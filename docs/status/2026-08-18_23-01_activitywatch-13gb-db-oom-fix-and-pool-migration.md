# Status: ActivityWatch 13GB DB / OOM Incident — Fix & Pool Migration

**Date:** 2026-08-18 23:01 CEST
**Scope:** This session only — aw-server I/O storm diagnosis, DB surgery, watcher re-tuning, Nix declarative wiring for HDD-pool migration.
**Verdict:** Runtime fixes live and verified. Declarative config builds green. Pool migration armed but **not yet deployed** (needs `nix run .#deploy`).

---

## Incident Summary

- btop showed `aw-server` at "6.05G / 100% IO" → actually **disk I/O**, not RAM.
- `aw-watcher-utilization` polled every **5s** with **~7.5KB** full-system JSON dumps (32 per-core CPU %, cumulative counters, loadavg, disk/net/sensors).
- Bucket 26 grew to **1.71M events / 12.1GB** = 99.98% of `sqlite.db` (13GB total; all other 50 buckets ≈ 1.5MB).
- Any query touching that bucket made aw-server scan gigabytes: **3.2GB RSS, 8.2GB disk reads in 75 min** → **repeated GLOBAL OOM kills** (journal: `oom-kill ... global_oom`, restart counter 9 between 18:10–18:14; gnome-keyring also killed later; 21Gi of 28Gi swap in use).
- Side effect discovered: a **246MB stuck offline queue** in `aw-client/queued/` (watcher couldn't flush while the server crash-looped).

---

## a) FULLY DONE (verified live)

1. **Root-cause diagnosis** — DB forensics (per-bucket sizes via sqlite, /proc/io, cgroup, kernel journal): utilization bucket bloat → OOM loop. Confirmed with `dbstat`: `events` table 13GB, freelist 0 (real data, not bloat).
2. **Full pre-surgery backup** — `VACUUM INTO` consistent copy → `~/backups/activitywatch-sqlite-preDecimation-13GB.db` (328s, integrity-checked).
3. **DB surgery** — stopped `activitywatch.target`, decimated bucket 26 to **1 sample/hour** (kept `MIN(id)` per hour), `VACUUM INTO` compact:
   - 1,741,918 events → 34,247 total (bucket 26: 1,710,710 → 3,035)
   - **sqlite.db: 13GB → 28MB**; `PRAGMA integrity_check` = ok; all 51 buckets intact
   - History span preserved: 2026-04-05 → 2026-08-18 (hourly)
4. **Queue backlog handled** — drained naturally once server stable (1,046 live rows), then the flushed 5s-density backlog was decimated too (4,180 → 3,038 in bucket 26). Queue now 0 rows.
5. **Watcher re-tuned at runtime** — replaced the read-only nix-store toml symlink with a real file (`poll_time = 300`). Empirically verified: events now arrive every ~5 min (22:45:41, 22:50:41...). HM `backupFileExtension = "backup"` makes the file/symlink collision safe on next deploy.
6. **Declarative `poll_time = 300`** — `platforms/common/programs/activitywatch.nix` with full incident rationale in comments. Eval-verified (`nix eval` → `{"poll_time":300}`).
7. **Pool migration module** — `modules/nixos/services/activitywatch-data-to-pool.nix`, house pattern (copied from `data-to-pool-migration.nix`): self-neutralizing root oneshot (ConditionPathIsDirectory-gated), stops user units for a consistent SQLite copy, `btrfs subvolume create`, `rsync -aHAX` → checksum dry-run must be zero-diff → owner sync → `rm -rf` source → symlink cutover → restart from pool. `onFailure` Discord alert, harden + capability set for btrfs/chown, ioTier.background.
8. **Wiring complete** — enabled in `configuration.nix`, btrbk-pool subvolume `services/activitywatch` in `snapshots.nix`, deploy-time start in `scripts/deploy.sh` (no-block, same as the /data migration).
9. **Full system build green** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` exit 0 (twice: pre- and post-formatter; a parallel session also wrapped the module in `flake.nixosModules` and the daemon committed it).
10. **System memory record** — incident + design + gotchas added to `SystemNix/AGENTS.md` ("Other Services").
11. **Disk space** — trashed 13GB original removed from trash (verified-redundant copy); `/` went 23G → **36G free**.
12. **Final health check** — aw-server: 0 restarts in 40 min, 15MB RSS, 11MB total disk reads (was 8.2GB), API serving 51 buckets.

---

## b) PARTIALLY DONE

1. **The deploy itself** — everything is built/wired but `nix run .#deploy` has NOT run. Until then:
   - The declarative `poll_time` and migration unit are not activated (runtime file carries the fix meanwhile).
   - Data still lives on NVMe; no pool copy; no btrbk coverage of activitywatch.
2. **13GB raw backup disposition** — parked on `/` (96% full). Compress/move/delete decision open. It's the only copy of the 5s-resolution history.
3. **Offline-queue file** — `aw-client/queued/.../data.db` still occupies **246MB on disk with 0 rows** (SQLite freelist never vacuumed). The migration will copy all 246MB needlessly.

---

## c) NOT STARTED

1. Retention automation — nothing prunes the utilization bucket going forward (even hourly + 300s cadence grows unbounded: ~1.6MB/day payload + 288 samples/day).
2. Payload-size reduction — the ~7.5KB event body (32 per-core %, cumulative counters like `ctx_switches` that are meaningless historically) is untouched; upstream `aw-watcher-utilization` has no trim option.
3. `.ini` config cleanup — `aw-watcher-utilization.ini` still says `poll_time = 5` (dead file: aw-core 0.5.17 reads the toml; empirically proven by the 300s cadence), but it lies to future readers.
4. Monitoring coverage for the failure class — no Gatus/system-health alert would catch an aw-server OOM crash-loop today (it's a user unit; unclear if the failed-unit collector sees user units).
5. Empty monitor365-era buckets — 34 of 51 buckets are monitor365 junk (screenshot/photo/network/notification, all empty) cluttering the DB and UI.
6. Compressing the pre-decimation backup (zstd would likely crush the JSON to ~1-2GB).

---

## d) TOTALLY FUCKED UP (honest list)

1. **Asked the user to run `sudo mkdir`** when the repo already contained the exact house pattern (`data-to-pool-migration.nix`: deploy-time root unit for agent sessions without sudo). User response: _"just fucking use nix"_ — correct. **Lesson: search repo conventions BEFORE requesting manual intervention.**
2. **Silently never applied the `.ini` edit** — the `multiedit` failed in the same tool block as the toml read-only failure and I never revisited it. Saved only by the empirical discovery that aw-core ignores the ini. The file is now misleading.
3. **Question tool misuse** — three failed `question` calls (empty `type`, missing `description`) before the options landed. Wasted round trips.
4. **~13 min ActivityWatch downtime** during the first decimation pass (stop → 705s DELETE + VACUUM → restart). Acceptable for a personal tracker, but a `PRAGMA journal_mode` + batched delete would have been faster.
5. **Backup temporarily doubled disk usage** — `VACUUM INTO` wrote 13GB while the original still existed, pushing `/` to 97%. Never checked free space before starting. No failure occurred, but on a fuller disk this would have been an outage.

---

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Search-first rule for operational asks** — the sudo-mkdir mistake would not happen with a mandatory "grep the repo for an existing pattern before asking the user to do anything manual" step. The repo encodes hard-won procedures precisely so agents don't improvise.
2. **Cross-edit verification discipline** — when a multi-tool block has partial failures, re-verify EVERY target, not just the one that blocked progress. The ini lie survived because only the toml path was load-bearing.
3. **Disk-space preflight for big writes** — before any multi-GB copy/VACUUM, check `df` and pick the target accordingly (the pool had 14T free).
4. **Unbounded-growth check for every collector** — this is the second 1 Hz-class sampler incident (ClickHouse `metric_log` was the first, per AGENTS.md). Any new watcher/exporter should get a retention story at introduction time, not after a 13GB discovery.
5. **Gatus/user-unit coverage** — the monitoring the monitor story covers system services well; user-session services (activitywatch, quickshell daemons) have no crash-loop alert. The 2026-08-18 OOM storm was noticed by a human reading btop.
6. **Parallel-session awareness** — a second session fixed my module (flake wrapper) mid-flight. Good outcome, but I only noticed via `git log` accident. Check `git log`/status before AND after long-running background work.

---

## f) NEXT UP (prioritized)

**Deploy-critical (blocks the happy live):**

1. Run `nix run .#deploy` (user) — activates declarative poll_time + starts the pool migration.
2. Watch `journalctl -u activitywatch-data-to-pool` through copy → verify → symlink cutover (first run of brand-new script; expect the possibility of a fix round).
3. Verify post-migration: `ls -la ~/.local/share/activitywatch` is a symlink; aw-server journal shows DB path resolving through it; first btrbk snapshot at 23:45 includes `services/activitywatch`.
4. Verify the runtime toml → store symlink converges on deploy (HM backup file `.backup` appears, poll_time still 300).

**Data hygiene:**
5. VACUUM the 246MB/0-row persistqueue `data.db` before the migration copies it (or accept the 246MB).
6. Compress the 13GB pre-decimation backup with zstd (likely ~1-2GB), then either keep on `/` or move to `/mnt/pool/archive/` with a provenance README.
7. Delete the misleading `.ini` (or sync it to 300) once toml convergence is confirmed.
8. Drop the 34 empty monitor365-era buckets from the DB (cosmetic + UI clutter).

**Prevention (stops the incident class):**
9. Retention automation: user timer that decimates bucket 26 to daily after 30d / hourly after 7d (or simply re-runs the hourly decimate monthly).
10. Patch `aw-watcher-utilization` upstream to trim payloads (drop cumulative counters + per-core arrays, keep aggregates) — house rule: app bugs fixed upstream, SystemNix consumes the flake bump.
11. Add aw-server health to system-health collector (probe `:5600/api/0/buckets` + user-unit state) with a Gatus alert.
12. Consider `MemoryMax` on the aw-server user unit so a future pathological query dies alone instead of triggering global OOM.
13. Document the "btop IO column misread as RAM" trap in AGENTS.md (cost me one diagnostic round).

**Backup disposition (needs user call):**
14. Decide backup fate: compress-and-keep vs move-to-pool vs delete (see question 2).

**Optional polish:**
15. Add activitywatch data age/staleness to backup-coordination once it's on the pool (btrbk snapshots, not backup-coordination, cover it — maybe skip).
16. Sweep `~/backups/` for other stale multi-GB artifacts while `/` is at 96%.
17. Re-check overall memory pressure (21Gi swap used) — outside this incident's scope but observed live.

---

## g) QUESTIONS (cannot determine myself)

1. **When should I trigger the deploy?** The migration briefly stops ActivityWatch (~2-5 min for ~300MB) — now, or a quieter moment? (I cannot run `nix run .#deploy` — it needs your sudo.)
2. **The 13GB raw backup: compress to zstd on NVMe, move to the pool archive, or delete outright?** It is the only copy of the 5s-resolution history; the live DB retains hourly samples. My recommendation: compress locally, keep 30 days, then delete.
3. **Retention policy for the utilization bucket going forward:** keep hourly samples forever (current state), or add automated decimation (e.g., daily granularity after 3 months)? At ~288 rows/day forever is ~105k rows/year — harmless on the pool, but the ClickHouse lesson says unbounded collectors always come back to bite.

---

_Report generated from session memory only — no new research performed._
