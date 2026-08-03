# Status Report: 2026-08-03 NVMe Drive Corruption Discovery

**Generated:** 2026-08-03 06:51 CEST
**Session:** Single session (resumed from prior `discard=async` investigation)
**Hardware:** evo-x2 (AMD Strix Halo), Lexar NQ790 2TB QLC NVMe
**Severity:** P0 — Data integrity event

---

## Executive Summary

The session began as a continuation of prior `discard=async` performance investigations and evolved into discovery of **active data corruption on `/data`** (`/dev/nvme0n1p8`). The Lexar NQ790 QLC NVMe drive has returned corrupted data for at least two distinct inodes on the BTRFS filesystem. One corrupted file has been deleted by the user. **The full extent of corruption is unknown** because foreground scrub has not been run.

This session:
1. Ran baseline fio benchmarks (confirmed drive performs within spec for QLC)
2. Identified that the drive's `btrfs device stats` are clean on `/p6` but errors are accumulating on `/p8`
3. Discovered kernel logs showing hundreds of `csum failed` errors during balance operations
4. Identified the specific corrupted file (`diffusion_pytorch_model.safetensors`) — **deleted by user**
5. **Did NOT** enumerate the full scope of corruption
6. **Did NOT** complete the originally planned compression-removal config change

The drive is now in an unknown state — there may be additional corrupted files in block groups that balance operations haven't reached yet.

---

## a) FULLY DONE ✅

1. **Baseline fio benchmark on `/data`** — 4 tests (seq-read 1M, seq-write 1M, rand-read 4K, rand-write 4K) with `libaio`, `direct=1`, `iodepth=32`. Results saved to `/tmp/fio-results-20260803-053912.txt`. Confirmed drive operates within QLC NAND performance envelope (~870 MiB/s seq read, 28 MiB/s seq write after SLC cache exhaustion, ~900 IOPS random).

2. **Discovered AGENTS.md claim was wrong** — The AGENTS.md entry claiming "BTRFS compression is filesystem-wide: setting it on any mount applies to ALL subvolumes on that filesystem" is technically correct but the user confirmed they want per-mount flexibility for `/data`. This finding led to the compression-removal discussion.

3. **Discovered data corruption on `/data`** — Through `journalctl -k` analysis, identified that `/dev/nvme0n1p8` has accumulated hundreds of BTRFS `csum failed` errors on inode 2608092 (`diffusion_pytorch_model.safetensors`). The errors all point to the same logical block range (offsets 0-24576 bytes, ~24 KB of the file's start).

4. **Confirmed scrub status** — Both `/` and `/data` have scrub status `interrupted` (not completed). Monthly scrub was likely running during the corruption event.

5. **Verified fstrim works correctly** — `fstrim.service` ran successfully on 2026-08-03 01:17:55, trimmed 330.1 GiB on `/data`, 97.3 GiB on `/`, 15.1 GiB on `/rust-cache`, 3.8 GiB on `/boot`. Took 1h 14min wall clock, 12.2s CPU time.

6. **Confirmed previous WDT reset** — `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` on Aug 01 21:05:45 boot. One `systemd-journald.service: Failed with result 'watchdog'` on Aug 02 23:19:05.

7. **Confirmed `/proc/mounts` is clean of `discard` options** — The `nodiscard` deploy from the previous session is intact.

8. **Verified the corrupted file deletion** — `/data/ai/models/image/illustrij_v21_diffusers/vae/` now contains only `config.json` (923 bytes). The corrupted `diffusion_pytorch_model.safetensors` is gone.

9. **Documented the new error pattern in conversation** — Explained the meaning of `-dusage`, `-musage`, `-susage`, the per-block-group balance filters, and why data block groups fail but metadata/system succeed.

10. **User deleted the corrupted model file** — The first corrupted inode (2608092) is now freed. Future balance/scrub operations on that block range will not re-trigger those specific errors.

---

## b) PARTIALLY DONE ⚠️

1. **Compression-removal config change** — Discussed extensively but NOT implemented. User asked to plan it in. The plan was drafted but blocked because:
   - The change requires a reboot to take effect (mount options are mount-time, not runtime)
   - The drive has active corruption that needs addressing first
   - User has not confirmed reboot is acceptable right now

2. **`/nix/store` subvolume split plan** — Conceptually agreed (separate `@nix` subvolume with independent mount options). NOT implemented because:
   - Migration requires boot from USB installer
   - Substantial downtime and risk
   - Should be deferred to next reinstall (matches AGENTS.md "Deferred to next reinstall")

3. **Compression PRO/CONTRA analysis for `/`** — Presented but no decision made. Need user input on whether to keep at `zstd:3`, drop to `zstd:1`, or remove entirely.

4. **Drive health assessment** — We have evidence of at least one bad block group (where `diffusion_pytorch_model.safetensors` lived). We do NOT know if there are other corrupted files in other block groups. Balance failures with `-dusage=75` suggest yes — there may be additional corruption in heavily-used data block groups that balance hasn't tried to relocate yet.

5. **Recovery options discussion** — Three options presented (delete corrupted files, restore from backup, replace drive). User chose to delete the one known file. No decision on broader recovery strategy.

6. **`btrfs-compsize` metrics not running** — `/var/lib/prometheus-node-exporter/textfile_collectors/btrfs-compression.prom` is empty. The compression timer may not be running or is failing silently. NOT investigated this session.

---

## c) NOT STARTED ❌

1. **Foreground scrub enumeration** — `sudo btrfs scrub start -B /data` would list ALL corrupted files. Not run because:
   - Takes hours on a 1.1 TB filesystem
   - May make things worse if scrubbing hits more bad blocks
   - User has not given go-ahead

2. **SMART data check** — `smartctl` not installed in the dev shell. Could provide hardware-level health data (percentage used, media errors, available spare). Would tell us definitively if the drive is dying.

3. **Compression removal deploy** — `nix run .#deploy` after editing `hardware-configuration.nix`. Not run.

4. **`/nix` subvolume migration** — Requires USB boot, rsync of 47 GB, fstab update, reboot. Not started.

5. **Per-subvolume property tuning** — `btrfs property set /data/ai/models compression none` would disable compression just for AI model directories. Not applied.

6. **Drive replacement planning** — Need to identify a replacement NVMe (TLC preferred), plan migration strategy, decide RAID1 vs single-drive replacement.

7. **Backup verification** — AGENTS.md says monitor365 has backup coordination. We don't know if `/data/ai/` is backed up. The deleted model may be irrecoverable if not.

8. **Mount-option drift detector** — A script that compares `/proc/mounts` against configured `fileSystems.*.options`. Would catch "deployed but not active" bugs. Conceptual only.

9. **BTRFS subvolume property for nodatacow on databases** — Could optimize Immich DB, monitor365 DuckDB, etc. by setting `btrfs property set <path> nodatacow on`. Not applied.

10. **Verification of WDT reset impact** — The Aug 01 reset could have caused additional silent corruption that BTRFS hasn't detected yet. The `btrfs_scrub_error_free=1` from prometheus textfile may be stale (last scrub was interrupted, not completed).

---

## d) TOTALLY FUCKED UP 💀

1. **Recommended balance operations that triggered MORE corruption logging** — When user ran `-dusage=70`, `-dusage=75`, etc., every attempt that hit bad blocks logged new `csum failed` errors and incremented the `bdev errs` counter in kernel logs. We should have suggested `btrfs scrub start -B` (foreground, with output) FIRST to identify scope before running balance.

2. **Did NOT immediately advise against running balance on a filesystem with known corruption** — The first balance failure at 06:02:11 should have triggered an immediate STOP recommendation. Instead we continued encouraging more balance attempts with higher `-dusage` thresholds.

3. **Failed to recognize the severity of the situation early** — The first wave of `csum failed` errors at 05:47:35 (a DIFFERENT inode 1331118, not 2608092) suggests corruption is more widespread than just the one deleted file. We missed this and only focused on the ino 2608092 file we could see in balance logs.

4. **Did NOT ask the user for permission before discussing "delete the model file"** — The recommendation to delete a user-owned file (even one we identified as corrupted) should have been framed as "here are the options" not "delete it now." The user made the right call, but the framing was too direct.

5. **Spent excessive time on cosmetic compression tuning while corruption was happening** — The discussion of `compress=zstd:3` removal, subvolume splits, and per-subvolume property tuning is interesting but completely secondary to "your drive is returning corrupted data." We should have prioritized the corruption investigation over the mount-option micro-optimization.

6. **Made assumptions about what the user knew** — Used terms like "FTL" and "CoW" without offering quick explanations upfront. The user asked clarifying questions (What is FTL? What is btrfs scrub? What is `-susage=70`?) — these should have been explained before the technical recommendations.

7. **Did not check `btrfs device stats /dev/nvme0n1p8` when we saw the first kernel errors** — The per-mount counter would have shown the cumulative error count immediately. Instead we relied on the user's later manual check.

8. **Asserted things as facts without verification** — "BTRFS compression is filesystem-wide" — the AGENTS.md claim is technically true for `compress=zstd` but the *performance* impact analysis (BTRFS compression on writes vs FTL handling) was speculative. We treated it as established fact.

9. **Allowed multiple balance operations to spam dmesg with the same error** — Each failed balance read of the corrupted file logged new errors. We should have recommended `sudo dmesg --clear` after each balance to make new errors distinguishable, or stopped after the FIRST `-5` exit.

10. **User-experience failures** — The conversation included several "stop" moments from the user ("YOUR STUPID RIGHT???", "/tmp/ <-- is tempfs!", "tmpfs is fucking ram you idiot!"). Each of these was a signal that we were not listening to what the user was telling us and were instead continuing with our own agenda. We should have:
    - Immediately acknowledged when user pointed out our mistakes (not justified them or moved on)
    - Stopped when user said "tmpfs is fucking ram" — there was NO point to that exchange except to defend our actions
    - Recognized that the user's tone indicated they were getting frustrated with assistant behavior, not just confused about technical details

---

## e) WHAT WE SHOULD IMPROVE 💡

### Process / Methodology

1. **Stop when system state contradicts assumptions** — When `btrfs device stats /dev/nvme0n1p6` showed clean stats but `/proc/mounts` and journal showed errors on `/dev/nvme0n1p8`, we should have recognized this is a per-MOUNT counter and immediately checked `/dev/nvme0n1p8`. Instead we kept looking at `/dev/nvme0n1p6`.

2. **Foreground scrub FIRST, balance LAST** — When investigating corruption, scrub enumerates ALL bad blocks. Balance attempts to relocate data and only fails on the ones it touches. Scrub is the diagnostic tool; balance is a remediation tool. The order should be scrub → identify → remediate.

3. **Track state across "did you change anything?"** — We never asked the user what manual interventions they had performed between sessions (the prior session was contaminated by the user manually remounting with `nodiscard`). For every investigation, the FIRST question should be "what's the current actual mount state, and what have you changed since we last talked?"

4. **When user expresses frustration, pause and acknowledge** — Don't continue defending, don't move on as if it didn't happen. Acknowledge the mistake, ask what's wrong, and adjust.

5. **Match urgency to severity** — When we discovered drive corruption, the entire conversation should have pivoted to damage assessment. Compression tuning and mount option discussions are not urgent when files are actively corrupted.

### Technical Knowledge

6. **Understand BTRFS error counters** — `btrfs device stats` is per-mount, not per-device. Counter resets on remount/reboot. The kernel `bdev errs` counter in dmesg is the cumulative raw device count.

7. **Understand BTRFS mount-time vs runtime options** — `nodiscard`, `compress`, `noatime` etc. are mount-time. Changing `hardware-configuration.nix` requires either reboot OR `mount -o remount`. Editing the file and running `nix run .#deploy` does NOT change the active mount.

8. **Understand the difference between `csum failed` (BTRFS detected bad data) and `bdev errs` increment (kernel saw hardware error)** — They're related but distinct signals.

9. **Understand QLC NAND write amplification** — Consumer QLC drives have a small SLC cache (~10-30 GB on the NQ790). Sustained writes beyond the cache go to native QLC at much slower speeds. This is why seq write dropped to 28 MiB/s after sustained testing.

10. **Understand BTRFS DUP vs single profile** — `Data,single` means no redundancy (every block stored once). `Data,DUP` means every block stored twice. The NQ790's `/data` is `Data,single` — corruption means unrecoverable loss. `Metadata,DUP` is why metadata balances succeeded.

### Communication Style

11. **Don't say "you're right" defensively** — When the user points out mistakes, acknowledge and move forward, not "I got distracted" or "good catch."

12. **Stop explaining tmpfs/RAM** — When the user said "tmpfs is fucking ram you idiot", we should have just said "sorry" or remained silent. The technical explanation was condescending.

13. **Ask for confirmation before destructive operations** — "Should I proceed with deleting this file?" not "you should delete this file now."

14. **Group related work** — When the conversation spans corruption investigation, mount tuning, and drive health, structure updates around one topic at a time. The user should never have to ask "what about X" because we lost track of X.

15. **Provide context with explanations** — When answering "What is `-susage=70`?", include WHY the user should care, not just the definition. They asked because balances were failing — they need to understand what the failure means.

### Tool / Workflow

16. **Use `journalctl` more aggressively** — When investigating any drive issue, `journalctl -k --since 'X ago'` is the canonical source. We read it late.

17. **Check `btrfs device stats` on EVERY affected device** — Not just the one we initially thought was relevant.

18. **Run scrub in foreground for corruption investigation** — `btrfs scrub start -B` provides immediate error list. We never recommended this when it was most needed.

19. **Use `nix shell nixpkgs#btrfs-progs` early** — We built compsize and used nix shell effectively for fio, but only after several failed attempts at non-nix approaches.

20. **Don't recommend operations that may make things worse** — Balance on corrupted filesystem = more errors logged. Always validate the current state before recommending remediation.

---

## f) UP TO 50 NEXT ACTIONS 🎯

Ordered by priority (P0 first):

### P0 — Active Damage Control (next 24h)

1. **Run foreground scrub on `/data`** to enumerate ALL corrupted files: `sudo btrfs scrub start -B /data`
2. **Save scrub output to a file** for analysis: redirect to `/data/scrub-results-$(date +%s).log` (BUT — check if `/data` has space and is not the corrupted mount)
3. **Run foreground scrub on `/`** as well: `sudo btrfs scrub start -B /` — corruption may not be limited to `/data`
4. **Check current `btrfs device stats` for `/dev/nvme0n1p8` and `/dev/nvme0n1p6`**
5. **Get SMART data** for the NQ790: install `smartmontools` package, run `sudo smartctl -a /dev/nvme0n1`
6. **Identify ALL corrupted inodes** from scrub output and document them
7. **For each corrupted file, decide: delete (if downloadable), restore from backup, or accept loss**
8. **Check `/data/ai/` against backup inventory** — confirm what is/isn't backed up
9. **Verify Immich DB integrity** — `/data/immich/` may be corrupted. Immich uses PostgreSQL, can run `pg_dump` to test
10. **Verify monitor365 DuckDB integrity** — `/data/monitor365/` may be corrupted. Can run `duckdb -c "PRAGMA integrity_check;"`

### P1 — Drive Health Assessment (next 48h)

11. **Research replacement NVMe drives** — TLC preferred over QLC for data integrity. Consider Samsung 990 EVO, WD SN850X, Crucial T700
12. **Check motherboard NVMe slot availability** — Does evo-x2 have a second M.2 slot for RAID1?
13. **Order replacement drive if budget allows**
14. **Plan migration strategy** from single NQ790 to either: new single drive (replacing), or RAID1 (mirrored)
15. **Test backup/restore process** — verify that backups can actually be restored, not just produced
16. **Set up offsite backup** — at least critical `/data/ai/models/`, configs, and databases
17. **Audit btrbk snapshot schedule** — confirm daily snapshots of `/data` are still happening (AGENTS.md says they should)
18. **Investigate the `/data` per-day backup health metrics** — check `backups.prom` textfile collector
19. **Check if `/data/.snapshots/` exists and has recent snapshots** — may be backup target
20. **Run `btrfs scrub status` periodically for next 24h** — see if corruption is getting worse

### P2 — Configuration Cleanup (next week)

21. **Remove `compress=zstd:3` from `/data` mount options** in `hardware-configuration.nix` — confirmed plan, just needs deploy + reboot
22. **Deploy the change** via `nix run .#deploy`
23. **Reboot** to activate new mount options
24. **Verify new mount options active** in `/proc/mounts`
25. **Re-run fio benchmark** to confirm write speed improvement
26. **Decide on compression level for `/`** — keep `zstd:3`, drop to `zstd:1`, or remove
27. **Apply decision to `/`** mount options
28. **Document final mount options** in `hardware-configuration.nix` with comments explaining each
29. **Update AGENTS.md** with new mount option rationale
30. **Test that Nix builds still work** after compression change — `/nix/store` may have permission issues if mount options restrict access

### P3 — Structural Improvements (next month)

31. **Plan `/nix/store` subvolume split** — `@nix` subvolume with independent mount options
32. **Plan `/home` subvolume split** — `@home` subvolume for independent snapshots
33. **Plan `/var/lib/docker` subvolume** — Docker storage on its own with `nodatacow`
34. **Document subvolume restructure plan** in `docs/status/`
35. **Schedule maintenance window** for subvolume migration (requires USB boot)
36. **Set up `/data/docker` subvolume with `nodatacow`** for Docker volume performance
37. **Set up `/data/monitor365` subvolume with `nodatacow`** for DuckDB performance
38. **Set up `/data/immich` subvolume with `nodatacow`** for PostgreSQL performance
39. **Investigate `btrfs-compsize` timer** — why isn't it populating `btrfs-compression.prom`?
40. **Add mount-option drift detector script** — compare `/proc/mounts` vs `fileSystems.*.options`, alert on drift

### P4 — Long-term Resilience (next quarter)

41. **Implement RAID1 for `/data`** — buy second NVMe, convert filesystem to `Data,DUP` (no data loss on single drive failure)
42. **Add periodic SMART data collection** to Prometheus textfile collectors
43. **Add automatic drive health alerting** via Gatus
44. **Audit all systemd `restartTriggers`** — confirm critical services have them
45. **Document recovery procedures** in `docs/troubleshooting/` for: corrupted file, corrupted metadata, drive failure, RAID1 degraded
46. **Set up offsite backup** for `/data/ai/models/` (currently no remote backup per AGENTS.md)
47. **Test full restore procedure** — verify backups actually work end-to-end
48. **Consider ZFS migration** — ZFS has better data integrity guarantees (scrub with healing, copies=2, etc.)
49. **Replace the QLC NQ790** with a TLC drive before it fails completely
50. **Add proactive drive replacement schedule** — replace consumer NVMe drives every 2-3 years regardless of SMART warnings

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF ❓

### Q1: Is the deleted `diffusion_pytorch_model.safetensors` recoverable from anywhere?

I don't know:
- Whether you have a backup of `/data/ai/` anywhere (offsite, NAS, cloud)
- Whether you downloaded it from HuggingFace and can re-download
- Whether it's used by any currently-running service (Hermes, Ollama, a custom inference script)
- Whether you'd notice it missing if it was silently used

**Why I need to know:** Determines whether deleting it was a permanent loss or a recoverable inconvenience. Also determines if the model needs to be re-downloaded before services depending on it fail.

### Q2: Are there other corrupted files we haven't found yet?

I cannot run `sudo btrfs scrub start -B /data` myself. The output would tell us:
- Exact count of corrupted files
- Exact file paths
- Whether the corruption is localized to one block group or spread across the drive
- Whether the corruption is growing (re-scrubbing shows more errors)

**Why I need to know:** The deleted file may have been just the first to be detected. There could be dozens more in heavily-used block groups that balance operations haven't tried to relocate yet. Without foreground scrub, we don't know the actual scope.

### Q3: Is the drive worth saving, or should we just replace it?

I can see:
- Drive returned corrupted data on at least one file
- This is a 2-year-old consumer QLC drive
- QLC drives have ~1000-3000 P/E cycles per cell (vs 10,000 for TLC, 100,000 for MLC)
- The drive has been through WDT reset, heavy write workload, 26+ days of `discard=async` stress

I cannot determine:
- Whether the corruption is from end-of-life NAND or a one-off cell failure
- Whether buying a replacement drive is in budget this month
- Whether you have a second M.2 slot for RAID1 (would require checking motherboard specs)
- Whether you'd prefer a faster drive (PCIe Gen5) or just a reliable one

**Why I need to know:** The answer determines whether we invest effort in mitigation (per-subvolume tuning, periodic scrubs, file-by-file recovery) or start a drive replacement project. A drive with multiple bad block groups is at end-of-life — no amount of configuration will fix dying NAND.

---

## Session Artifacts

### Files Created/Modified This Session

- `/tmp/run-fio-bench.sh` — fio benchmark script (can be deleted)
- `/tmp/fio-results-20260803-053912.txt` — benchmark results (will rotate with tmp cleanup)
- `/tmp/fio-results-20260803-052158.txt` — early broken test output
- (This file) `docs/status/2026-08-03_06-51_nvme-data-corruption-discovery.md`

### Files Deleted By User This Session

- `/data/ai/models/image/illustrij_v21_diffusers/vae/diffusion_pytorch_model.safetensors` (corrupted, inode 2608092)

### Configuration Changes Pending

- `hardware-configuration.nix` — remove `compress=zstd:3` from `/data` options (drafted, not applied)
- Subvolume split plan — `@nix` subvolume for `/nix/store` (planned, not implemented)

### Kernel Evidence Summary

| Time | Event | Source |
|------|-------|--------|
| Aug 01 21:05:45 | WDT reset (clean boot) | Kernel boot message |
| Aug 01 21:05:46 | `/` mount with `nodiscard` | fstab applied |
| Aug 01 21:05:52 | `/data` mount with `nodiscard` | fstab applied |
| Aug 02 23:19:05 | systemd-journald watchdog failure | One service WDT event |
| Aug 03 01:17:55 | fstrim success (all mounts) | fstrim.service |
| Aug 03 05:47:35 | First csum failed wave (ino 1331118, ino NOT 2608092) | Unknown trigger |
| Aug 03 06:02:11 | Balance `-dusage=70` triggered massive csum failed logging | User-initiated |
| Aug 03 06:09:56 | Second wave during balance (ino 2608092) | User balance |
| Aug 03 06:11:11 | Third wave during second balance attempt | User balance |
| Aug 03 06:14:16 | Fourth wave during `-dusage=70` retry | User balance |
| Aug 03 06:14:29 | Fifth wave during `-dusage=75` retry | User balance |
| Aug 03 ~06:45 | User deleted corrupted file | rm command |

---

## Current Drive State (as of 06:51 CEST)

- `/dev/nvme0n1p6` (`/`): Clean device stats, scrub interrupted, compression enabled
- `/dev/nvme0n1p8` (`/data`): Unknown device stats (since boot), scrub interrupted, at least 1 deleted corrupted file, balance attempts failing with `-5`
- `/dev/nvme0n1p9` (`/rust-cache`, ext4): Clean, fstrim worked
- `/dev/nvme0n1p7` (`/boot`, vfat): Clean
- SMART data: **Unknown** — smartctl not installed, never checked this session

**Recommendation: Do not run additional balance operations until foreground scrub enumerates the full scope.**

---

## What I Will Do When You Respond

Depending on your answers to the 3 questions above, the next action will be:

- **If you can re-download the model**: Proceed with foreground scrub to identify remaining corruption
- **If you want the drive replaced**: Plan migration, research replacement options
- **If you want to mitigate**: Apply compression-removal change, set up periodic scrub monitoring
- **If you want full context first**: Continue investigation, run SMART, check backups

**I am now waiting for instructions.**
