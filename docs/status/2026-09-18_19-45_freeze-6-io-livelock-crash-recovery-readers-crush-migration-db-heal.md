# Freeze #6 — 2026-09-18 19:28:11 — IO-livelock again: crash-recovery readers (crush-DB migration + discordsync heal + cold cache) under ~27 agent sessions

Boot `0a1c9584` (up since 15:32:07, kernel 7.2.6 — the post-freeze-5
reboot) froze at **19:28:11.892848** — journal cut mid-stream inside a
signoz rule-eval line, no panic, no shutdown record, `/var/crash` empty
(no vmcore), WDT silent: the scheduler-livelock class (freezes
#1/#3/#4/#5). Hard reset → boot `250f1591` at 19:31:14.

The guard caught the class all afternoon and could not stop it: **16
Zone-6 action-taken trips in boot -1 (#466 15:37:08 → #481 19:25:40,
one per 10-min cooldown)** — flm socket + btrbk churn units sacrificed,
storm continued, box died 2.5 min after the last trip. The guard's own
death-adjacent log line names the class verbatim:
`I/O PSI some avg60=42.95% sustained (max disk busy 97.5%, MemAvailable=61.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)`.

## Timeline (all 2026-09-18, boot `0a1c9584` unless noted)

| Time | Event |
| --- | --- |
| 15:32:07 | Boot after freeze-5 hard reset. Cold page cache: everything re-reads from QLC |
| 15:32:57 | `crush-hot-db-migrate` starts (the structural fix) **and** `discordsync-db-heal` starts — simultaneously |
| 15:35:39 | First migration lands (`1ATemplate`); interleaved `migrated <repo>` lines from here |
| 15:37:08 | Guard Zone-6 trip #466 — repeats every cooldown window for the rest of the boot |
| 15:42:57 | `discordsync-db-heal` start **times out at 10 min** — only 1.1G of the 11G DB read (3.15s CPU over 600s wall = disk saturated) → OnFailure alert |
| ~16:32 | First migration run ends: `Failed with result 'signal'` after **59m54s, 23.2G read, 4.5G written** (killed mid-copy — consistent with the ~16:44 deploy's unit restart) |
| ~16:44 | Deploy lands **system-785**; migration restarts, immediately `skip: crush session(s) active (27)` and exits clean — **the migration does NOT run again this boot**; the 27 concurrent crush sessions (nix evals, flake updates, go tests, session-DB churn on QLC) carry the storm alone from here |
| 17:00→19:28 | Sustained QLC saturation; guard trips #468→#481; PSI avg60 41-79% |
| 19:25:40 | Guard trip #481 (last action-taken) |
| 19:27:02→19:28:03 | Rapid-fire `nix-daemon accepted connection` burst from parallel agent sessions (evals/builds) |
| 19:28:11.892 | Journal cut mid-line. Livelock death. No shutdown record |
| 19:31:14 | Boot `250f1591` (current) |

## Root cause: the crash-recovery window is itself an IO storm

Same livelock class as #3/#5 — memory healthy (MemAvail 56-80% all
afternoon), QLC NVMe 100% busy for hours, scheduler dies. What stacked
THIS time:

1. **crush-hot-db FIRST migration** — the fix for the base storm class
   is itself a multi-hour full-disk reader: ~260 projects × multi-GB
   `.crush` DBs copied QLC→Samsung, 23.2G read in its first 60-min run
   alone, `ioTier.background` (BE/6). BFQ ionice does NOT reduce total
   bytes: full-disk reads saturate QLC NAND regardless of priority
   (freeze-3 lesson, restated).
2. **discordsync-db-heal 11G integrity check at every boot** — after a
   hard crash it re-verifies the whole DB; under saturation it cannot
   finish inside its 10-min budget (timed out boot -1, restarted boot 0,
   still in D-state scanning 8+ min in). A crash-loop amplifier: every
   crash re-runs it into the post-crash cold cache.
3. **Post-crash cold page cache** — the 15:32 boot re-read every binary,
   library, and DB page from the QLC while (1) and (2) were already
   streaming.
4. **~27 concurrent crush sessions** — the documented base class (this
   is what the migration exists to fix): parallel `nix eval` / `nix flake
   update` / `nix develop go test` / journalctl sweeps, all QLC-rooted,
   the visible burst right before death.
5. **`compsize /data`** — full-filesystem extent scan observed in
   D-state on boot 0 (minor contributor, same class).

Guard gap: `ioChurnUnits` (btrbk ×3, balance ×2, scrub ×3) does not
include `crush-hot-db-migrate`, `discordsync-db-heal`, or ad-hoc scans —
the actual readers of this storm are outside the sacrifice list, so
Zone 6 fired 16× and changed nothing.

## State on boot 0 (19:31 → report time 19:44) — storm STILL LIVE

- io PSI some avg10 57.9% / avg60 60.7% at 19:44 (peaked avg60 **79%**,
  disk busy 100%, MemAvail 79%); guard trip **#482** already fired;
  flm socket down (restore waits for IO drain).
- Migration resumed and is progressing: past `openapi-for-a-team` /
  `plugmarket` / `project-discovery-daemon` — roughly the `p`-names,
  ~2/3 through the project list. It converges; each crash-reboot merely
  interrupts and resumes it.
- `discordsync-db-heal` restarted at boot, still scanning (D-state);
  discordsync service itself healthy and serving 200s throughout.
- D-state census at 19:35: `sqlite3 integrity_check` (heal), `mv
  nobletary/.crush → /mnt/hot` (migration), `nix eval`, `nix flake
  update`, `nix develop go test`, `journalctl`, `node_exporter` —
  the stacked-reader roster in one snapshot.
- Deploy state CLEAN: `/run/current-system` == profile == system-785
  (anchored; no freeze-5-style unanchored generation, no pending
  re-deploy obligation). Tree has `_forgejo-scripts.nix` modified
  (owning session).

## Follow-ups

1. **Immediate (owner decision):** if the box freezes again before the
   migration completes, stop the two resumable readers at the NEXT boot
   and let the box settle: `sudo systemctl stop crush-hot-db-migrate
   discordsync-db-heal` — both are idempotent/next-run-converges. The
   migration is the fix, but finishing it on a calm box beats crash-
   looping through it.
2. **Guard: extend `ioChurnUnits`** with `crush-hot-db-migrate.service`
   and `discordsync-db-heal.service` (both resumable oneshots — exactly
   the churn contract) so Zone 6 can actually drain this storm class.
3. **discordsync-db-heal cadence:** a full 11G integrity check at EVERY
   boot is a standing crash-amplifier under load. Gate it (ConditionPath
   exists on a dirty-shutdown marker, or stretch TimeoutStartSec and
   accept the delay) — decide in the discordsync module.
4. **Serialize the migration** through the `heavy-job` wrapper slot
   count (or per-project throttle) if it ever needs re-running on a busy
   box — first-run evidence says a bare 60-min 23G+ read storm is
   freeze-adjacent by itself.
5. Cap concurrent agent sessions during post-crash recovery windows —
   27 sessions eval-ing into a cold cache + streaming readers is the
   exact stack that died. The `system_crush_sessions` metric exists;
   consider a sev1-notify threshold tie-in during guard-active windows.
6. btrbk: Zone-6 churn-stops killed sends again this boot (heals via
   `btrbk-pool-clean`); verify tonight's 23:00 root send lands once the
   storm drains.
