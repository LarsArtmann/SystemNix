# Memory-Emergency-Guard — Zone 6 Runbook

**Module:** `modules/nixos/services/memory-emergency-guard.nix`
**Companion module:** `modules/nixos/services/sev1-escalation.nix` (desktop tier)
**VM test:** `tests/test-memory-emergency-guard.nix`

---

## What the guard does

A 30-second oneshot (`memory-emergency-guard.timer` → `memory-emergency-guard.service`) evaluates six trip zones. On ANY trip it stops FastFlowLM, its activation socket, and the resumable I/O churn units (btrbk root/data/pool, both balances, all three scrubs). The socket is restored automatically once memory margins recover AND sustained io PSI has drained below the strict restore bar (`restoreIoSomeAvg60ThresholdPercent`, default 20 — half the Zone 6 trip bar) AND the daily restore budget (default 3) is unspent. The io gate landed 2026-10-25: the restore gate was memory-only, so during a Zone 6 storm (memory gauges healthy, io saturated) the socket restored straight into the storm, the 21.6 GB cold load re-tripped, and the budget burned before noon — capped by 12:34Z with every LLM consumer (browser-history, PMA, paperless enricher) 503ing until a manual `systemctl start fastflowlm.socket`.

**Zone-6 action split (2026-10-28 §7.1a, RATIFIED, live since the 2026-10-28 deploy):** zone 6 (IO) trips no longer touch sockets/sacrifice AT ALL. Action table:

| Trip class                    | Cooldown                      | Action                                                                                                                                                                      | Restore                                                                                             |
| ----------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Zones 1–5 (memory)            | `actionCooldownSeconds` 600   | stop sockets + sacrifice + churn units (unchanged legacy path)                                                                                                              | legacy 4-axis restore gate + budget                                                                 |
| Zone 6 (IO), `ioPause.enable` | `ioActionCooldownSeconds` 150 | **SIGSTOP headless driver process groups** named by the per-trip io.stat attribution (config-owned `ioPause.cgroupPatterns`, capped `maxPauseGroups`); sockets stay SERVING | auto SIGCONT at io PSI avg60 < 20 sustained `calmSeconds` (600), hard cap `maxPausedSeconds` (3600) |
| Zone 6 escalation             | —                             | ≥3 zone-6 trips with trees already paused ⇒ the writer is outside the pausable set ⇒ churn-unit stop (STILL never the socket stop)                                          | churn re-arm path                                                                                   |

The **never-PTY invariant is the hard safety layer**: a process group is pausable only when NO member holds a controlling terminal (one /proc pass builds the tty-owning pgid set; any overlap is skipped + logged) — owner interactive work is structurally unpausable, honoring the 2026-10-07 SIGSTOP-license revocation by construction. Pause state: `stateDir/io-paused` (epoch + pgids), metrics `memory_emergency_guard_io_paused_groups` + `io_pause_epoch_seconds`. The sustained-storm latch (§7.1c) adds `memory_emergency_guard_sustained_storm` (≥2 trips/h held ≥2 h, or ≥20/boot) with its own Gatus check.

evo-x2 configures `socketUnits = []` and `sacrificeUnits = []` (FastFlowLM is gone since 2026-11-05), so a memory-zone trip there stops the I/O churn units only and logs `MEMORY EMERGENCY action taken: I/O churn units only (no socket or sacrifice unit is configured: observe-only mode)`. The script is built in two shapes (that one and the VM node's), and `checks.x86_64-linux.memory-emergency-guard-host-shape-build` builds the evo-x2 shape on every check run: a helper called with an empty list once rendered as a zero-argument call and made the evo-x2 toplevel unbuildable for five hours (2026-11-26).

## IO-PAUSE selection (rewritten 2026-11-26)

Until 2026-11-26 the selection had never paused anything (13,311 zone-6 trips, 0 pauses: the cgroup walk kept the `/io.stat` suffix on each path, so no `cgroup.procs` resolved, and it ranked by lifetime bytes). The selection runs at the trip action only and costs nothing between trips:

1. **Two cgroup samples** `sampleSeconds` apart (default 3 s). Their delta is the only basis for a pause: it is what moves data NOW. The delta against the previous trip can be hours old on the first trip of a storm and would freeze an idle heavyweight.
2. **Driver**: delta at least `minDriverRateMB` (8 MB/s) and at least `minDriverTopSharePercent` (25 %) of the largest mover in the sample, path contains a `cgroupPatterns` entry, and the cgroup is not a `*.slice`. The `MEMORY EMERGENCY IO-TOP (trip #N, zone 6, 3s sample)` line names the top movers with a `[pattern]`, `[no pattern]` or `[slice]` tag whether or not anything is pausable.
3. **Never-PTY invariant** (the hard layer, unchanged): one `/proc` pass builds the tty-owning process-group set; a group with a member that holds a controlling terminal is skipped with a log line.
4. **Stall evidence** (new): inside the sample window the guard reads every thread's state about every 0.2 s. A group counts as I/O-stalled when one of its threads was in D state in at least a quarter of the passes. The cgroup's bytes are evidence against a process group only when the cgroup is ONE tree: a `*.service` holding exactly one process group (a model loading). A `*.scope` (login session, app, `systemd-run` scope) and any cgroup holding several process groups are bags of unrelated trees: the sshd-session monitor of a login, the nix-daemon listener beside its workers and builds. There every group needs its own stall evidence, and a bystander is skipped with a log line.
5. **Cap**: `maxPauseGroups` (8) counts process GROUPS. When it is reached the pause line says so, and further drivers wait for a later trip.

Why 4 and 5 exist: on the first live day of the two-sample selection the guard applied a cgroup's bytes to every headless group inside it. It froze the sshd-session monitor of seven logins for an hour each, twice the nix-daemon listener (every nix build on the box hung, 07:55 to 08:55 and again from 17:16), and one trip took 10 groups against a cap of 8 (the cap was checked once per cgroup).

**Readers.** `/proc` and cgroupfs are read with `find -print0` and one awk that opens each file by `getline`. `find -exec awk {} +` hands awk the paths as ARGUMENTS, and gawk treats an unopenable argument as fatal: one process or cgroup vanishing between the listing and the read dropped every later entry while find still exited 0 (measured 2026-11-26: 919 of 1,686 lines in one of four passes; a fresh process missed in 34 of 40 passes under churn). `checks.x86_64-linux.guard-reader-shape-selftest` pins the shape; `nix run .#guard-sim -- host` proves it against the real built script (the `vanishservice` scenario fails on every pre-fix build: `nix run .#guard-sim -- --live` runs the same scenarios against the script that is running right now). `nix run .#guard-sim -- --units host` runs the four unit-call legs (memory trip, restore, churn re-arm and its hold window, backup catch-up slot, the zone-6 escalation) against a recording systemctl stub.

**Journal lines of one zone-6 trip:** `IO-TOP (trip #N, zone 6, 3s sample): <movers>`; zero or more `IO-PAUSE skip: pgid N in <cgroup> holds a controlling TTY ...` or `... was not I/O-stalled in the trip sample (k of n passes with a thread in D state) ...`; then exactly one of

- `IO-PAUSE (trip #N, zone 6): SIGSTOPped K headless driver process group(s) <pgids> [drivers:<cgroup>(pgid N, D k/n) ...]`,
- `IO-PAUSE (trip #N, zone 6): NO eligible headless tree matched the attribution ... (<reason>)`, where the reason names why nothing was pausable (no pattern covers any driver; pattern cgroups move data but none is a driver; a matching group holds a TTY; groups beside others were not I/O-stalled; no live headless process; process scan or cgroup walk unavailable, in which case nobody is paused),
- `IO-PAUSE (trip #N, zone 6): NO new tree matched ... existing pause kept`.

With `ioPause` on, a zone-6 trip logs NO `action taken` line. `scripts/deploy.sh` (trip-recency gate) and `scripts/crash-triage.sh` therefore count `IO-PAUSE (trip` lines as trips (fixed 2026-11-26: both counted `action taken` only and had seen none of the 2,679 zone-6 trips of the preceding nine days).

**Persistence.** The trip identity is fsynced (`sync FILE`, an fsync of that file) before the journal line. Until 2026-11-26 it was `sync -f`, a syncfs of the whole root filesystem booked to the guard's cgroup: a median 29.7 MB written per trip run, up to 543 MB, with wall times up to 268 s.

### Releasing a group the guard froze

The guard resumes on its own at io PSI avg60 below 20 % sustained 600 s, or at the hard cap (`maxPausedSeconds`, 3600 s). To release a bystander earlier (worked example 2026-11-26: the nix-daemon listener and an sshd-session monitor, both frozen by the selection bug described above):

```bash
sudo cat /var/lib/memory-emergency-guard/io-paused            # epoch, then one "pgid cgroup" line per group
ps -eo pid,pgid,stat,etimes,args | awk '$2 == <pgid>'         # read the WHOLE group before signalling it
sudo kill -CONT -- -<pgid>                                    # the leading minus addresses the process GROUP
```

Leave the line in `io-paused`: the guard's own resume sends another SIGCONT, a no-op for a running group. Do not release the build tree beside it; that pause is the guard's mitigation. Never signal by pattern (`pkill -f`): it matches production units.

| Zone | Signal                                                  | Class                                                                                     |
| ---- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 1    | MemAvailable < 5%                                       | absolute floor                                                                            |
| 2    | MemAvailable < 10% AND zram ≥ 92%                       | shmem-unevictable trap                                                                    |
| 3    | PSI mem avg10 ≥ 40% AND zram ≥ 80%                      | refault-thrash                                                                            |
| 4    | PSI mem avg60 ≥ 50% alone                               | slow-burn stall                                                                           |
| 5    | episodic avg10 leaky bucket ≥ 8                         | the calibrated 2026-08-31 freeze                                                          |
| 6    | **io PSI some avg60 ≥ 40% AND max per-disk busy ≥ 20%** | **crash #3: stacked full-disk readers livelock the scheduler while memory looks healthy** |

## Zone 6 semantics (what stops, what never auto-restarts)

On a Zone 6 trip the guard stops the following. On evo-x2 (`ioPause.enable`) a zone-6 trip stops NONE of them unless the escalation ladder fires (three zone-6 trips with driver trees already paused); the list is the legacy zone-6 path and the escalation target.

- `fastflowlm.socket` + `fastflowlm.service` — restored automatically by the guard (budget permitting).
- `btrbk-root.service`, `btrbk-data.service`, `btrbk-pool.service`, `btrfs-balance-metadata.service`, `btrfs-balance-data.service` — **RE-ARMED by the guard automatically** once sustained io PSI drains (some avg60 < 40, the Zone 6 trip threshold): on the first tick that sees BOTH the threshold and a stop at least `ioActionCooldownSeconds` (150 s) old the guard `systemctl start --no-block`s exactly the units it recorded stopping, counts the re-arm in `memory_emergency_guard_churn_rearms_total`, and clears the churn-window metrics. The minimum stop window landed 2026-11-26: the io PSI value is read before a run's trip action, so a memory trip on a box with calm io used to re-arm the units it had just stopped in the same run, and a PSI hovering at the bar re-armed on the first run under it. While the window is young the journal says `GUARD CHURN-REARM HELD`. Without the re-arm a mid-receive stop pushed the nightly btrbk send a full +24h (the timer had already fired), and a second storm in the 3-day freshness window FAILED the backup check (2026-09-16 23:00 trip #299 class). Each unit's own pre-start guards decide whether it is safe to run; a relapse re-trips within one 30 s tick. btrbk resumes incrementally from the newest common snapshot (no manual re-seed ever needed — the DAS-outage semantics); an interrupted receive is healed by `btrbk-pool-clean`. <!-- format:allow -->
- `btrfs-scrub@-.service`, `btrfs-scrub@data.service`, `btrfs-scrub@mnt-pool.service` — the btrfs-scrub TEMPLATE INSTANCES (2026-09-29 phantom fix: the list previously named the stray unit files `btrfs-scrub--`/`btrfs-scrub-data`/`btrfs-scrub-mnt-pool` that systemd never starts, so the scrub stop was a silent no-op while the 2026-09-28 storm scrub read 5.9 TB). `systemctl stop` on the correctly-named instance stops the KERNEL-side scrub: the nixpkgs template carries `Type=simple` + `ExecStop=btrfs-scrub-maybe-cancel` (runs `btrfs scrub cancel`; killing the CLI waiter alone does not). **NEVER re-armed by the guard**: btrfs scrub has NO resume — a restart re-reads the filesystem from byte 0, and the trip→drain→re-arm cycle over an oscillating PSI was the freeze-#7 restart loop (432 trips / 37 h / zero completions). A guard-killed scrub stays dead until its own weekly timer window; the coverage gap is Gatus-visible via the never-finished btrfs-health scrub metrics (same as the deferral-skip path). To resume a scrub early, run it manually in a quiet window: `sudo systemctl start 'btrfs-scrub@-.service'` (the scrubGuard deferral in its ExecStart re-checks PSI/zram/heavy readers).

- `inboxclean-web.service` is NOT a churn unit (moved 2026-11-27 to `ioPause.cgroupPatterns`). It was enrolled on 2026-10-23 as the top unit reader of that storm, but a churn entry is stopped by EVERY trip action whether or not it moves data, and each stop took the dashboard's `:8099` listener with it (plain web service, no socket unit), so the InboxClean Gatus checks paged on guard stops: from 2026-11-26 06:38 to 2026-11-27 02:12 the zone-6 escalation stopped it 25 times (7.2 h down, 36 % of the window, five alert episodes of "InboxClean Projections Ready") while none of the 135 IO-TOP samples of that window named it as a mover. As a pause pattern it is SIGSTOPped only when the trip sample measures it as a driver, and its socket stays open. Live since gen-1033 (2026-11-27 10:28): the 101 zone-6 escalations of the following 23 h left it running, and no trip paused it. Diagnosis recipe for an InboxClean alert whose unit journal shows `Stopping InboxClean` with no deploy: `journalctl -u memory-emergency-guard --since <window> --grep 'io escalation|churn units re-armed'` (every stop lands within 3 s of an `io escalation` line, every start of a `re-armed` line). A user-facing service with a listener does not belong on the churn list; the pause patterns are its tool.

**Manual cancel during a storm is SANCTIONED operator behavior (codified 2026-10-01, fifty-todos).** The proven use case: 2026-09-28 02:27:41-02:28:37, interactive `sudo btrfs scrub cancel /` + `sudo btrfs scrub cancel /data` (read 549.8G and 656.3G respectively at cancel time) stopped the storm scrub the guard could not touch (the guard sat in ACTION COOLDOWN at those exact seconds — its initial "the churn-stop did it" attribution was WRONG, corrected by sudo-journal forensics; the actor sat on pts/22+pts/20 and stays UNATTRIBUTED — user vs agent session is an open owner question, `docs/status/2026-09-30_00-31_task-000001a0ef17061c3d535dd0d65b00000000.md` §g3). Mechanism to expect: a cancelled kernel scrub (-125) makes the `btrfs scrub start -B` waiter exit 1 regardless of the error summary; the template's `SuccessExitStatus = [ 1 ]` (deployed 2026-09-29) treats that as success so the units do NOT park FAILED and exit-4 later deploys. Exit 3 (errors found) still fails the unit by design — see the exit contract in `docs/agents/storage.md`. After cancelling, do NOT restart the scrub mid-storm: btrfs scrub has NO resume and a restart re-reads the filesystem from byte 0 (the freeze-#7 loop class); wait for the weekly window or a quiet-window manual start.

**How to re-arm btrbk manually** (only if the guard itself is wedged/dead and you need the send now):

```bash
sudo systemctl start btrbk-root.service btrbk-data.service btrbk-pool.service
```

Only do this once io PSI has actually drained (`cat /proc/pressure/io` — some avg60 < 40), otherwise the restart just re-stacks full-disk readers and the next guard tick stops them again. Check what the guard stopped at the last trip via the metrics (below) instead of the journal.

## Post-trip forensics is a prom read (2026-09-15)

`/var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom`:

- `memory_emergency_guard_zone6_trips_total` — Zone 6 trips since first deploy (counters persist in `/var/lib/memory-emergency-guard/zone-counts` across guard restarts AND reboots; no Gatus condition depends on counter monotonicity — the trip check keys on `last_trip_recent`).
- `memory_emergency_guard_io_psi_some_avg60_percent` + `memory_emergency_guard_io_disk_busy_percent_max` — the Zone 6 pair (busy is the phantom-PSI filter: D-state on dead automounts saturates io PSI with IDLE disks).
- `memory_emergency_guard_churn_units_stopped{unit="..."}` + `memory_emergency_guard_churn_stopped_timestamp_seconds` — WHICH units the guard actually stopped (were active pre-stop) and WHEN. Present only while the churn window is open; vanishes on the first run where io PSI avg60 falls back under the trip threshold.
- `memory_emergency_guard_last_run_timestamp_seconds` — freshness stamp. A frozen value means the guard is DEAD.
- `memory_emergency_guard_trips_this_boot` + `memory_emergency_guard_load_bearing` — the per-boot escalation pair (2026-10-25, task queue §f.10): trips since THIS boot started (lifetime counter minus a baseline that re-snapshots when the kernel boot id changes — per-boot, never lifetime drift; the identity is `/proc/sys/kernel/random/boot_id` since 2026-11-26: the earlier one, now minus uptime with both sides truncated to whole seconds, flipped between two values inside one boot and kept the count at 0 through a boot with about 300 trips) and the `loadBearingTripsPerBoot` (default 10) threshold flip. `load_bearing 1` = "the guard is load-bearing, root-cause the storm" — the freeze-#7 class (432 trips/boot) is a structural defect, not normal operation; churn_mode covers the hour-scale re-trip loop, this covers a whole boot of repeated containment. Gatus "Memory Guard Load-Bearing" notifies Discord on the flip (one episode = one message until trips fall back under the threshold); VM-tested by scenario 6a-lb (`tests/test-memory-emergency-guard.nix`, incl. the boot change via the `BOOT_ID_SRC` seam); `checks.x86_64-linux.guard-boot-id-selftest` pins the identity.
- Full attribution bundle per trip: `/var/tmp/io-psi-forensics-<ts>/` (cgroup io.stat, top offenders, D-state stacks) via the transient `io-psi-forensics` unit.

## Guard-death detection — the two layers

`node_exporter` serves a textfile's LAST content forever, so the "Memory Emergency Guard" Gatus check's presence pats CANNOT see a dead guard (the original check comment claimed "absent metrics" — wrong for textfile collectors). Two layers close the gap (2026-09-15):

1. **Desktop:** sev1 bridge `MEMORY GUARD DEAD` (guard .prom mtime older than `staleGuardSeconds` = 300s; notify tier after boot grace).
2. **Discord/Gatus:** the "Memory Guard Collector Fresh" check (system-health emits `system_memory_guard_metrics_fresh` from the .prom mtime; 0 = protection DOWN).

A Zone-6-shaped wedge (guard killed mid-trip with churn units stopped) is therefore visible: frozen textfile → fresh composite 0 → Gatus red, plus the stopped churn units are named by the churn metrics' last emission.

## Deploy gate vs guard Zone 6 — division of labor (no double-fixing)

Two different mechanisms cover the same IO-storm class — do not conflate them:

|              | `scripts/pre-deploy-check.sh` pressure gate                                         | guard Zone 6                                 |
| ------------ | ----------------------------------------------------------------------------------- | -------------------------------------------- |
| When         | deploy time only (`nh os switch` blocked, exit 12)                                  | continuous, every 30 s                       |
| Action       | REFUSES to deploy under pressure (some avg10 ≥ 20%, zram ≥ 90%, MemAvailable < 10%) | STOPS the churn sources + sacrifices flm     |
| Escape hatch | `DEPLOY_FORCE_PRESSURE=1`                                                           | none by design (sacrifice is the mitigation) |

A deploy blocked by the pressure gate is NOT a guard bug; a Zone 6 trip during a deploy is not a gate bug. The gate protects the ACTIVATION window; the guard protects the KERNEL.

## Threshold calibration evidence (2026-09-15, first real trips)

Zone 6 deployed 2026-09-14 with first-value thresholds (40% avg60 / 20% busy). Live telemetry from the first ~1.5 days (99 Zone 6 trips):

- Trips corroborate REAL stalls, not phantoms: observed io PSI some avg60 up to ~80-90% with `io_disk_busy_percent_max` at 100% — far above both thresholds. The disk-busy corroboration filter correctly passes these (real disk activity).
- The forensics bundle from a representative trip (2026-09-15T16:01Z, io avg60 79.87%, load 84): D-state tasks in `blk_mq_get_tag` on the DAS USB disk flush thread, `usb-storage` wedged in `usb_sg_wait`, user-session crush processes dominating cumulative cgroup io.stat. The driver is the known debt: crush session DBs on the QLC root + a stalling single USB DAS link — NOT the churn units the guard stops (those are victims/multipliers, not the root driver).
- Verdict: **thresholds unchanged.** 40/20 fire only on genuinely dangerous sustained states; raising them would delay protection against the exact crash #3 signature they were built for. The structural fix is the crush-DBs-off-QLC migration (`services.crush-hot-db`, gated on the /nix soak ~2026-09-17) and the owed reboot clearing the DAS USB state — both tracked in TODO_LIST.
- Trip cadence 6/hour during storms is the expected shape: each trip stops the churn units, io recovers, timers re-fire them, storm rebuilds. `restore_capped 1` bounds the flm side of that loop. If trips persist across days AFTER the crush-hot-db deploy, revisit this calibration with fresh forensics.

## io_uring completion-wait phantom (2026-11-26)

Ghostty's default `async-backend` is io_uring, and the kernel books a thread in an io_uring completion wait as IO-stalled once its ring has handled one request, disks idle or not. Four monitor windows (nvtop x2, iotop-c, btop, opened 2026-11-25 19:57) read 40-93% in their own `io.pressure` and held system io PSI at 40-65% for 20 h with every disk <= 5% busy: Zone 6 kept tripping on any real burst that crossed the 20% disk-busy bar, the churn escalations fired, and the deploy gate refused all 40 deploys of the day (its "IDLE disks" branch refuses as well). The IO-TOP line named llama-embeddings as top mover because its zram swap-out bytes dominate; byte movers are not the stalled tasks. `platforms/nixos/users/home.nix` now pins ghostty to `async-backend = "epoll"` (off-screen A/B: default backend ~60% cgroup io pressure, epoll 0.00%; live only after a deploy plus a full ghostty restart). When Zone 6 trips and the IO-TOP movers look too small for the PSI, rank cgroups by `io.pressure` (docs/agents/stability.md, IO-PSI attribution step 0) before touching thresholds or stopping units. Source: `docs/status/2026-11-26_15-48_memory-emergency-guard-autopsy-phantom-io-psi-ghostty-io-uring-status.md`.

## Backup starvation + bounded catch-up slot (2026-09-28)

Multi-day Zone-6 storms never drain under the 40% re-arm bar, so the nightly btrbk sends starved SILENTLY — 2026-09-26..28 the pool receives stopped for three nights while every 23:00 start was killed within seconds and zero re-arms fired (the storm drivers were other workloads; btrbk was collateral). The catch-up slot closes that gap:

- **`backupUnits`** (default the four btrbk units) — stopped on trip like any churn unit, but every REAL stop (re)writes `stateDir/backup-stopped.epoch`, a dedicated clock that survives churn-file rewrites (which drop inactive units and would otherwise erase the starvation record).
- **`backupStarvationSeconds`** (default 21600 = 6h): once the clock exceeds the budget AND io PSI some avg60 is below **`backupCatchupResumePercent`** (default 50 — deliberately ABOVE the 40 re-arm bar: backups may resume into a mild storm, never the extreme band at/above it), the guard GRANTS a slot: `systemctl start` of the backup units + **`backupCatchupProtectSeconds`** (default 900) during which trip actions SKIP them in the churn stop ("keeping … running through this trip action").
- After the slot expires, normal rules resume: a still-storming box re-stops the units at the next action and the clock restarts — the slot repeats at most once per starvation window. A full re-arm clears the clock (backups running again).
- **Metrics:** `memory_emergency_guard_backup_starved` (Gatus: "Memory Guard Backup Starved", line-anchored VALUE-0), `_backup_catchup_protected`, `_backup_catchup_slots_total`. A persistent `backup_starved 1` means even the slot could not run (io PSI never under the resume bar) — a manual quiet-window `sudo systemctl start btrbk-root.service` closes the gap.

## Log dedup + trip-line attribution (2026-09-28)

The cooldown-active and restore-capped steady-state lines used to log on EVERY 30 s run (live 2026-09-27: restore-capped every 30 s for hours). They now heartbeat at most once per **`verboseLogIntervalSeconds`** (600) per branch; action/transition lines always log immediately. Trip ACTION lines are self-attributing: at each action the guard walks per-cgroup `io.stat` (bounded depth, timeout 10, root cgroup excluded — the forensics-script pattern; zero steady-state cost), snapshots it in `stateDir/cgroup-io.last`, and appends the top-3 delta to the line — `top io since last trip: system.slice/… +1234MB, …`. The full forensics bundle (`/var/tmp/io-psi-forensics-*`, wired on every trip) remains the evidence gate; the trip line is the 10-second answer to "who is driving it".
