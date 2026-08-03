# Status Report: 2026-08-03 NVMe Drive Corruption Discovery

**Generated:** 2026-08-03 06:51 CEST (last updated 07:00 CEST)
**Session:** Single session (resumed from prior `discard=async` investigation)
**Hardware:** evo-x2 (AMD Strix Halo), Lexar NQ790 2TB QLC NVMe
**Severity:** P0-HIGH — Confirmed corruption, unknown scope, drive may be degrading

---

## Executive Summary

The session began as a continuation of prior `discard=async` performance investigations and evolved into discovery of **active data corruption on `/data`** (`/dev/nvme0n1p8`).

**Facts established this session:**
1. `/dev/nvme0n1p8` returned corrupted data on at least two distinct inodes (ino 1331118, ino 2608092)
2. The user deleted one corrupted file (`diffusion_pytorch_model.safetensors`, ino 2608092)
3. `btrfs balance` operations on `/data` consistently fail with `Input/output error` (`status: -5`) when targeting data block groups
4. `btrfs balance` on metadata and system block groups succeeds — corruption is data-only
5. The Lexar NQ790 is a consumer QLC drive that has experienced sustained stress: 26+ days of `discard=async` (since removed), WDT resets, heavy write workload

**Facts NOT established this session:**
- Total count of corrupted files
- Whether corruption is localized to one block group or spread across the drive
- Hardware-level drive health (SMART data never checked)
- Whether more corruption is occurring in real time or is from a single past event

**Anchored to AGENTS.md:**
- Prior status reports: `docs/status/2026-07-08_*` (discard-related) and `docs/status/2026-06-25_*` (WDT reset investigation)
- AGENTS.md line 209 (TRIM section, updated 2026-08-02 to reflect `nodiscard`)
- AGENTS.md gotcha: "BTRFS metadata ENOSPC crash (2026-06-26)" — confirms this hardware has a history of filesystem-stress events
- AGENTS.md gotcha: "All snapshots are LOCAL-ONLY. If the NVMe fails, everything is lost. This is the #1 data loss risk (flagged since 2026-06-25)."

---

## a) FULLY DONE ✅

1. **Baseline fio benchmark on `/data`** — 4 tests (seq-read 1M, seq-write 1M, rand-read 4K, rand-write 4K) with `libaio`, `direct=1`, `iodepth=32`, 8 GiB file, 30s runtime. Results at `/tmp/fio-results-20260803-053912.txt`. Confirmed: ~870 MiB/s seq read, ~28 MiB/s seq write (after SLC cache exhaustion), ~900 IOPS random.
2. **Discovered corruption on `/data`** — `journalctl -k --since '30 days ago' | grep -iE 'nvme|btrfs.*error'` revealed 100+ `csum failed` events on `/dev/nvme0n1p8`. Inode 2608092 (`diffusion_pytorch_model.safetensors`) and inode 1331118 (path unknown — only seen in initial 05:47:35 wave).
3. **Identified corrupted file path** — `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors`, corrupted at offsets 0–24576 (~24 KB of file start).
4. **Verified corruption pattern** — All errors are `mirror 1` failures, indicating `Data,single` profile (no BTRFS-level redundancy on this data). The drive returned bad data that BTRFS's checksum caught.
5. **Confirmed scrub was interrupted** — Both `/` and `/data` scrub status = `interrupted` per `/var/lib/prometheus-node-exporter/textfile_collectors/btrfs.prom`.
6. **Verified fstrim.service works** — Ran successfully 2026-08-03 01:17:55, trimmed 330.1 GiB on `/data`. Confirmed `nodiscard` deploy from prior session is intact (`/proc/mounts` clean of `discard` options).
7. **Confirmed WDT reset history** — `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` on Aug 01 21:05:45 boot. One `systemd-journald.service: Failed with result 'watchdog'` on Aug 02 23:19:05.
8. **Mapped failure modes by block group type** — `-dusage=N` (data) fails with EIO; `-musage=N` (metadata) and `-susage=N` (system) succeed. This is diagnostic: corruption is in data block groups only.
9. **Verified deletion of corrupted file** — `/data/ai/models/image/illustrij_v21_diffusers/vae/` now contains only `config.json` (923 bytes). The corrupted file's block range is now unallocated.
10. **Documented explanation of `-dusage`/`-musage`/`-susage`** — In conversation, explained why data balances fail and metadata/system succeed.

---

## b) NOT STARTED ❌ (renamed from "Partially Done" for honesty)

The "Partially Done" section in the prior draft conflated "discussed but not done" with "in progress." Below is the honest accounting — **zero configuration changes were deployed this session**.

### b.1) Discussed, Not Implemented

1. **Compression-removal change to `/data`** — Plan drafted (drop `compress=zstd:3` from `/data` mount options in `hardware-configuration.nix`). Not applied. **Blocked by**: requires reboot to take effect (mount options are mount-time, not runtime); corruption investigation takes priority; user has not confirmed reboot is acceptable right now.
2. **`/nix/store` subvolume split plan** — Conceptually agreed (separate `@nix` subvolume with independent mount options). Not implemented. **Blocked by**: requires USB installer boot; substantial downtime; matches AGENTS.md "Deferred to next reinstall" note.
3. **Compression PRO/CONTRA analysis for `/`** — Discussed but no decision made. Needs user input on whether to keep `zstd:3`, drop to `zstd:1`, or remove entirely.
4. **`btrfs-compsize` metrics not populating** — `/var/lib/prometheus-node-exporter/textfile_collectors/btrfs-compression.prom` is empty (header only, no values). The compression timer may not be running or is failing silently. **Not investigated**.

### b.2) Recommended But Not Executed (Requires Root)

The following require `sudo` which is not available in this session's execution environment:

5. **Foreground scrub enumeration** — `sudo btrfs scrub start -B /data` would list ALL corrupted files. User has not run it.
6. **Current `btrfs device stats` for `/dev/nvme0n1p8`** — Would show cumulative error count since boot. User's earlier check showed 0 (BEFORE the balance operations that triggered the bulk of errors).
7. **SMART data check** — `smartmontools` not installed in dev shell. `sudo smartctl -a /dev/nvme0n1` would provide hardware health (percentage used, media errors, available spare).
8. **Immich DB integrity** — `pg_dump /data/immich/postgres` would test PostgreSQL consistency.
9. **monitor365 DuckDB integrity** — `duckdb -c "PRAGMA integrity_check;" /data/monitor365/monitor365.duckdb` would test DuckDB.
10. **`/data/.snapshots/` check** — Verify btrbk snapshots exist and are recent (AGENTS.md says daily snapshots should occur).

---

## c) TOTALLY FUCKED UP 💀

### c.1) Technical Mistakes

1. **Recommended balance operations on a filesystem with known corruption** — When the user reported the first `Input/output error` from `-dusage=70`, we should have immediately recommended STOP and switch to foreground scrub. Instead we encouraged more balance attempts with higher `-dusage` thresholds (`80`, `90`, `95`, `75`). Each failed balance logged additional `csum failed` errors, growing the kernel `bdev errs` counter.
2. **Missed the first corruption wave at 05:47:35** — The kernel log shows `csum failed root 5 ino 1331118` at 05:47:35 — a DIFFERENT inode than the 2608092 file we focused on. Inode 1331118's file path is unknown (not in the balance-triggered logs, only in the initial wave). We never investigated whether inode 1331118 has additional corruption.
3. **Did not check `btrfs device stats /dev/nvme0n1p8` early** — When we saw kernel `bdev errs` increment in dmesg for `/p8`, the per-mount `btrfs device stats` counter would have confirmed the cumulative count immediately. Instead we relied on the user's later manual check.
4. **Asserted AGENTS.md's "BTRFS compression is filesystem-wide" as fact** — Technically true for `compress=zstd` semantics, but the *performance* analysis (BTRFS compression overhead vs FTL handling) was speculative. We treated inference as established fact.
5. **Did not clear dmesg between balance attempts** — When balances failed, we should have recommended `sudo dmesg --clear` to make new errors distinguishable from accumulated old ones.

### c.2) Process Mistakes

6. **Spent extensive time on compression tuning while corruption was active** — The discussion of `compress=zstd:3` removal, subvolume splits, and per-subvolume property tuning is interesting but completely secondary to "the drive is returning corrupted data." We should have pivoted immediately to damage assessment.
7. **Failed to recommend foreground scrub early enough** — The single most useful diagnostic (`btrfs scrub start -B`) was not mentioned until 50+ messages into the corruption discussion.
8. **Did not ask "what changed since last session?" first** — Prior session was contaminated by user manually remounting with `nodiscard`. We should always establish the current state before drawing conclusions.

### c.3) User-Experience Failures

9. **Multiple "stop" moments from the user were not properly handled** — User statements like "tmpfs is fucking ram you idiot!" and "YOUR STUPID RIGHT????" indicated frustration. We continued defending or explaining instead of acknowledging and adjusting. Specifically:
   - When user said tmpfs is RAM, we should have said "sorry, you're right" and moved on — the technical explanation was condescending
   - When user asked about tmpfs, we got distracted into explaining filesystem caching instead of addressing the actual concern
10. **Asked the user to confirm things we should have stated as facts** — e.g., "Should we proceed with deleting this file?" could have been "Here's the corrupted file. Three options: delete + re-download, restore from backup, or leave it. Which do you want?"

---

## d) WHAT WE SHOULD IMPROVE 💡

### d.1) Process

1. **Scrub first, balance last** — Scrub is the diagnostic tool (reads everything, identifies corruption). Balance is the remediation tool (moves data, only touches what it reads). When investigating corruption, ALWAYS start with `btrfs scrub start -B` for enumeration.
2. **Stop recommending operations after first failure** — If a command fails, do not recommend the same command with different parameters. Switch tools.
3. **Pivot the conversation to severity** — When a P0 issue is discovered, drop all other threads. Compression tuning is not urgent when files are corrupted.
4. **Establish state at session start** — "What's the current mount state? What have you changed since we last talked? What commands have you run?" before drawing any conclusions.
5. **Track inode paths from kernel logs** — `csum failed root 5 ino 1331118` → look up the inode → identify the file. We never did this for ino 1331118.

### d.2) Technical Knowledge

6. **`btrfs device stats` is per-mount, not per-device** — Counter resets on remount/reboot. Kernel `bdev errs` in dmesg is the cumulative raw device count.
7. **BTRFS mount options are mount-time** — `nodiscard`, `compress`, `noatime` etc. require reboot OR `mount -o remount`. Editing `hardware-configuration.nix` + `nix run .#deploy` does NOT change the active mount.
8. **`csum failed` vs `bdev errs` are distinct signals** — `csum failed` = BTRFS detected bad data via checksum. `bdev errs` increment = kernel saw hardware error. Related but separate.
9. **BTRFS `Data,single` = no redundancy** — Corruption in `Data,single` block groups is unrecoverable (no mirror). `Metadata,DUP` = always duplicated.
10. **QLC NAND write amplification** — Consumer QLC drives have small SLC cache (~10–30 GB). Sustained writes beyond the cache go to native QLC at 1/10th the speed.

### d.3) Communication

11. **When user is frustrated, acknowledge and move on** — No defensive explanations, no continuing the same point.
12. **Frame destructive recommendations as choices** — "Here are your options: A, B, C" not "You should do X."
13. **One topic at a time** — When conversation spans multiple issues, structure updates around one topic per response. The user should not have to ask "what about X?"
14. **Provide context with technical definitions** — When asked "What is `-susage=70`?", include WHY they should care (because balances are failing).

### d.4) Tooling

15. **`journalctl -k --since 'X ago'` early and often** — Canonical source for filesystem/hardware errors. We read it late.
16. **`nix shell nixpkgs#btrfs-progs` first** — Don't try non-nix approaches when nix shell provides everything.

---

## e) CONFIDENCE & OPEN QUESTIONS 🔍

### e.1) What's Certain

- The drive has returned corrupted data on at least one file (ino 2608092) — confirmed by BTRFS checksum logs
- A second inode (1331118) had corruption at 05:47:35 — confirmed by kernel log, but file path unknown
- The user's deletion of the corrupted file succeeded — confirmed by `ls` output
- `btrfs balance` consistently fails on `/data` data block groups — confirmed by 4+ failed attempts
- Metadata and system block groups are healthy — confirmed by successful `-musage`/`-susage` balances

### e.2) What's Probable (high confidence)

- **More corrupted files exist.** Each balance pass touched only specific block groups. Balance has not covered all 92% utilization. Foreground scrub would enumerate.
- **The drive is degrading, not having a one-off error.** Consumer QLC drives with WDT resets + sustained write workload + 26+ days of `discard=async` stress are exactly the failure mode we're seeing.
- **The deleted model file may be unrecoverable.** No evidence of offsite backup for `/data/ai/` (AGENTS.md says "All snapshots are LOCAL-ONLY").

### e.3) What's Probable (low confidence)

- **Hardware failure vs driver bug vs single bad block.** Could be any of these. SMART data would clarify.
- **The corruption is ongoing.** A single bad block from manufacturing would not produce this pattern (errors only during balance = reading unwritten data, not from prior usage).

### e.4) What's Unknown

- Total corrupted file count (requires foreground scrub)
- Specific file path for inode 1331118 (requires `btrfs inspect-internal inode-resolve 1331118 /` which needs root)
- Drive wear level (requires `smartctl -a`)
- Other drives' health (only `/dev/nvme0n1` partitions checked; `/dev/nvme0n1p6` and `/dev/nvme0n1p8` are same physical device but distinct partitions)
- Backup status of `/data/ai/`, `/data/monitor365/`, `/data/immich/` (requires reading backup coordination config + checking `/data/.snapshots/`)

### e.5) What Would Falsify Our Conclusions

| Hypothesis | Falsification |
|-----------|---------------|
| Drive is at end-of-life | SMART shows 0-50% usage, 0 media errors, 100% available spare |
| Corruption is widespread | Foreground scrub returns 0 corrupted blocks (only the deleted file had issues) |
| Corruption is ongoing | Re-scrub after 24h shows the same error count (no new errors) |
| Drive is healthy but bad blocks | SMART shows good health AND only 1-2 corrupted files total |
| Other mounts are also corrupt | Foreground scrub on `/` returns 0 errors |

---

## f) UP TO 50 NEXT ACTIONS 🎯

### P0 — Active Damage Control (next 24h)

1. **Run foreground scrub on `/data`** to enumerate ALL corrupted files: `sudo btrfs scrub start -B /data` — redirect to `/root/scrub-data-$(date +%s).log` (NOT `/data` — that mount may be unstable)
2. **Run foreground scrub on `/`** as well — corruption may not be limited to `/data`: `sudo btrfs scrub start -B /`
3. **Get SMART data for `/dev/nvme0n1`** — install `smartmontools`, run `sudo smartctl -a /dev/nvme0n1` (also `sudo smartctl -x /dev/nvme0n1` for full hex dump)
4. **Identify ALL corrupted inodes** from scrub output and document them in this report
5. **Check current `btrfs device stats`** for `/dev/nvme0n1p8` and `/dev/nvme0n1p6`
6. **Resolve inode 1331118** — `sudo btrfs inspect-internal inode-resolve 1331118 /data` (find the file path of the OTHER corrupted inode)
7. **For each corrupted file**, decide: delete (if downloadable from HuggingFace/HuggingFace mirror), restore from backup, or accept loss
8. **Verify Immich DB integrity** — `pg_dump /data/immich/postgres` or `pg_isready` + manual query
9. **Verify monitor365 DuckDB integrity** — `duckdb -c "PRAGMA integrity_check;" /data/monitor365/monitor365.duckdb`
10. **Stop touching `/data`** — no balance, no scrub (in background), no defrag, no large writes until corruption scope is known

### P1 — Drive Health Assessment (next 48h)

11. **Research replacement NVMe drives** — TLC preferred over QLC for data integrity. Compare: Samsung 990 EVO, WD SN850X, Crucial T700, Seagate FireCuda 530
12. **Check motherboard NVMe slot availability** for RAID1 — does evo-x2 have a second M.2 slot?
13. **Decide: replace drive vs add RAID1 vs continue mitigation** — based on SMART data + scope of corruption
14. **Plan migration strategy** if replacing — btrfs send/receive, fresh install, or live migration
15. **Verify backup/restore process** — confirm backups can actually be restored, not just produced
16. **Check `/data/.snapshots/` existence and recency** — btrbk snapshots may have captured pre-corruption state for some files
17. **Audit btrbk snapshot schedule** — confirm daily snapshots of `/data` are still happening
18. **Read `services.backup-coordination.backups` config** to know what's actually backed up
19. **Set up offsite backup** for critical paths (`/data/ai/`, configs, databases) — at minimum
20. **Investigate `btrfs-compsize` timer** — why isn't `btrfs-compression.prom` populating?

### P2 — Configuration Cleanup (next week, requires reboot)

21. **Remove `compress=zstd:3` from `/data`** in `hardware-configuration.nix` — confirmed plan
22. **Deploy** via `nix run .#deploy`
23. **Reboot** to activate new mount options
24. **Verify mount options active** in `/proc/mounts`
25. **Re-run fio benchmark** to confirm write speed improvement
26. **Decide compression level for `/`** — keep `zstd:3`, drop to `zstd:1`, or remove
27. **Apply decision** to `hardware-configuration.nix`
28. **Document final mount options** with comments explaining each
29. **Update AGENTS.md** with new mount option rationale
30. **Test Nix builds** after compression change

### P3 — Structural Improvements (next month)

31. **Plan `/nix/store` subvolume split** — `@nix` subvolume with independent mount options
32. **Plan `/home` subvolume split** — `@home` subvolume for independent snapshots
33. **Plan `/var/lib/docker` subvolume** — Docker storage on its own with `nodatacow`
34. **Document subvolume restructure plan** in `docs/status/`
35. **Schedule maintenance window** for subvolume migration (USB boot required)
36. **Set up `/data/docker` subvolume with `nodatacow`** for Docker volume performance
37. **Set up `/data/monitor365` subvolume with `nodatacow`** for DuckDB performance
38. **Set up `/data/immich` subvolume with `nodatacow`** for PostgreSQL performance
39. **Add mount-option drift detector script** — compare `/proc/mounts` vs `fileSystems.*.options`, alert on drift
40. **Add periodic SMART data collection** to Prometheus textfile collectors

### P4 — Long-term Resilience (next quarter)

41. **Implement RAID1 for `/data`** — buy second NVMe, convert filesystem to `Data,DUP` (no data loss on single drive failure)
42. **Add automatic drive health alerting** via Gatus
43. **Audit all systemd `restartTriggers`** — confirm critical services have them
44. **Document recovery procedures** in `docs/troubleshooting/`: corrupted file, corrupted metadata, drive failure, RAID1 degraded
45. **Test full restore procedure** end-to-end
46. **Consider ZFS migration** — ZFS has better data integrity guarantees (scrub with healing, copies=2)
47. **Replace the QLC NQ790** with a TLC drive before it fails completely
48. **Add proactive drive replacement schedule** — replace consumer NVMe every 2-3 years
49. **Add per-service data integrity monitoring** (PostgreSQL checksums, DuckDB integrity, file-level hashes for critical configs)
50. **Establish baseline performance metrics** so degradation is detectable before failure

---

## g) THREE QUESTIONS I CANNOT FIGURE OUT MYSELF ❓

### Q1: Is the deleted `diffusion_pytorch_model.safetensors` recoverable from anywhere?

**What I know:** The file was corrupted and you deleted it. HuggingFace models are typically re-downloadable. I don't know whether the model is in active use by any service.

**Why I need to know:**
- If it's in use by a running service (Hermes, Ollama, inference script), that service will silently fail or load broken data
- If you have it on HuggingFace cache or another machine, no action needed
- If it was your only copy, the deletion was permanent loss

**How this affects next steps:** If the model is needed and not re-downloadable, we need to find a copy ASAP before other drive failures could affect it.

### Q2: What's your decision on the drive — replace, mitigate, or monitor?

**What I know:** The drive has at least one corrupted file and likely more. SMART data would clarify if it's dying. You have local snapshots but no offsite backup (per AGENTS.md).

**The three realistic options:**
- **A) Replace now** — buy a TLC NVMe, migrate `/data`, accept that some AI models may be lost
- **B) Mitigate** — apply compression-removal fix, set up RAID1 (requires second NVMe), establish offsite backup, live with the risk
- **C) Monitor** — foreground scrub to enumerate corruption, daily SMART checks, replace when SMART crosses thresholds

**Why I need to know:** Each path requires different actions. Replacement is a 2-week project. Mitigation is this week. Monitoring is a habit change. The decision determines what I implement.

### Q3: Can you run `sudo btrfs scrub start -B /data` and share the output?

**What I know:** This command will enumerate ALL corrupted files on `/data` in foreground (takes hours on 1.1 TB). The output is text on the terminal.

**Why I need to know:**
- The exact count of corrupted files
- Whether the corruption is concentrated in one block group or spread
- Whether corruption is ongoing (errors that increase with re-scrub) or historical (stable count)
- Which specific files need recovery decisions

**If you can't run it yourself:** Confirm that I should add the recommendation to the next deploy script or systemd unit, so the next maintenance window catches it automatically.

---

## Session Artifacts

### Files Created This Session

- `/tmp/run-fio-bench.sh` — fio benchmark script (ephemeral)
- `/tmp/fio-results-20260803-053912.txt` — benchmark results (rotates with tmp cleanup)
- `/tmp/fio-results-20260803-052158.txt` — early broken test output (from missing libaio)
- (This file) `docs/status/2026-08-03_06-51_nvme-data-corruption-discovery.md`

### Files Deleted By User This Session

- `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors` (corrupted, inode 2608092)

### Configuration Changes Pending

- `hardware-configuration.nix` — remove `compress=zstd:3` from `/data` options (DRAFTED, NOT APPLIED)
- Subvolume split plan — `@nix` subvolume for `/nix/store` (PLANNED, NOT IMPLEMENTED)

### Evidence References

| Claim | Source |
|-------|--------|
| Drive returned corrupted data | `journalctl -k --since '30 days ago'` (paste_4.txt) |
| Two distinct inodes corrupted | `csum failed root 5 ino 1331118` (05:47:35), `csum failed ... ino 2608092` (06:09:56) |
| Balance failures on data blocks only | 4× failed `-dusage=N`, all `-musage/-susage` succeeded |
| Previous WDT reset | `x86/amd: Previous system reset reason [0x02000800]` on Aug 01 boot |
| fstrim working | `journalctl -u fstrim --since '30 days ago'` (paste_3.txt) |
| Drive wear / health | NOT CHECKED — `smartctl` not installed |

---

## Current Drive State (as of 06:51 CEST, last updated 07:00)

- `/dev/nvme0n1p6` (`/`): Clean device stats, scrub interrupted, compression enabled
- `/dev/nvme0n1p8` (`/data`): Unknown device stats (since boot), scrub interrupted, 1 deleted corrupted file, balance attempts failing with `-5`
- `/dev/nvme0n1p9` (`/rust-cache`, ext4): Clean, fstrim worked
- `/dev/nvme0n1p7` (`/boot`, vfat): Clean
- SMART data: **Unknown** — never checked this session

**Operational recommendation:** Do not run additional balance operations until foreground scrub enumerates the full scope of corruption.
