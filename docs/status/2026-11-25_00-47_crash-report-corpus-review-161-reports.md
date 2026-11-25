# Crash-Report Corpus Review: all 161 crash reports, 2026-02 → 2026-11-24

> Review session 2026-11-24 22:45 → 2026-11-25 00:47 CET, HEAD `267d5a8d1` at report time.
> Every crash report in the repo was read in full (161 files, 2.73 MB) and checked against the
> freeze ledger, the TODO surfaces and the live system. Method and caveats: §1 and §d.

## Verdict

1. **The crash rate has not moved in three months.** 59 whole-host crash ends in the 55 days
   since 2026-10-01 (1.07/day). About 95 since 2026-05-04: 24 before crashes were numbered,
   62 numbered cuts, 9 un-numbered cuts.
2. **The three root conditions named by the reports are unchanged:** a standing thermal
   ceiling (Tctl 98–99 °C during this review at load 6–95), unbounded concurrent agent load,
   and recovery boots that re-arm the same load.
3. **Fixes are shipped faster than they are verified.** Only 19 of 100 host-crash reports show
   live verification at report time. 59 of them record an earlier fix that never ran, was inert,
   was undeployed, or was dead code.
4. **The freeze ledger misses 11 crash boundaries,** and three same-day reports used numbers
   the ledger later gave to other cuts (#3, #5, #16). One ledger row is factually wrong (#46,
   corrected in this session).
5. **kdump has never captured a crash.** The crash kernel has been loaded since 2026-11-22
   19:53 and the two "panic-reboot" cuts since (#61, #62) left nothing. The panic label rests
   on one reset register that any software restart also sets.
6. **A kernel warning no report mentions** fires from `kswapd0` in 3 of the 8 retained dead
   boots, 8.5 and 20 minutes before the #60 and #61 cuts.
7. **Six crash reports' follow-ups were never harvested** and two TODO rows are stale.

## Live state at report time (READ THIS FIRST)

Boot `b4931451` is the freeze-#63 recovery boot (up since 2026-11-24 20:46:44). It spent the
whole review in the state the ledger calls "never-cooled":

| Time          | Tctl          | io PSI some avg10 | load (1 m) | What was running                                                                                                                                                                |
| ------------- | ------------- | ----------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 22:55         | (not read)    | 98.2 %            | 557        | 7 `ld.mold` linkers in D state, the top writer at 2.7 MB/s                                                                                                                      |
| 00:00         | 90 °C         | 40 %              | 13         | calmest point of the session                                                                                                                                                    |
| 00:43         | 99 °C         | 32 %              | 87         | 36 `crush` processes, 7 `java` (315 % CPU), 5 `go` (240 %), `govulncheck` (240 %), `buildflow` ×2, `shellcheck`, `execution.test`, six `btrfs-delayed-meta` kworkers in D state |
| 00:47         | 98 °C         | 36 %              | 22         | 37 `crush` processes                                                                                                                                                            |
| 01:09 → 01:10 | 62 °C → 96 °C | 38 %              | 13         | 38 `crush` processes; this session's 2-second scoped `nix fmt` eval ran inside that minute                                                                                      |

Five of the last recovery boots died 5 m 55 s to 7 h 57 m after boot while re-entering this
state (#48 8 m, #53 5 m 55 s, #60 55 m, #40 3 h, #47 7 h 57 m). Nothing was stopped: the
standing rule for a storm is measure, attribute, report, recommend (`docs/agents/stability.md`,
Build-Storm Runbook step 3). This review added at most three reader sessions at a time and
ran no builds.

## 1. Scope and method

**Corpus rule.** Every file under `docs/status/` (top level and `archived/`) whose file name
or H1 title matches crash vocabulary (freeze, crash, panic, WDT, watchdog, thermal trip, black
screen, a boot id), plus the four `crash-analysis-*` documents: 161 files, 2.73 MB. 141 came
from the file name, 20 from the title (appendix lists them all).

**Not read:** the 38 evidence pulls and task reports under `docs/status/tasks/`, the roughly
140 storm/OOM/livelock session statuses without crash vocabulary in name or title, and 7 HTML
reports. They are cited where a crash report cites them.

**Reading.** 13 date-ordered batches read by zai reader subagents (15 dispatches for 13 batches,
at most three at a time; three hit `429` rate limits: two were re-dispatched, one was recovered
from the file it had already written).
Each reader read every file completely and wrote one 19-field block per file (tier, kind,
events, reset, family, confidence, trigger, warning, foreseen, fixes, verification level,
retractions, open follow-ups, lessons, ledger diff, cross-references, flags). A script checked
161/161 blocks against the batch lists (exact path match, field order). Extractions live in
`~/.cache/crash-review/extract/B01–B13.md` (session-local, 1.0 MB).

**Verification levels used below.** `[V]` I checked it against the live system or the source
file. `[R]` reader-extracted from a report. `[S]` script tally over the extraction: a keyword
or first-token scan of report text, so an indicator, not a measurement.

**Method traps met (worth knowing).** `journalctl -k` means the *current* boot and returns
zero lines for any earlier boot. Wrapping `journalctl` in `timeout` returned nothing in this
shell. An awk tally used variables named `FS` and `RS`, which silently changed record parsing
until a known-value check (89 vs 1 host-crash blocks) exposed it.

## 2. The consolidated crash record

### 2.1 Tiers

| Tier               | Files | What they are                                                                                                                                                                           |
| ------------------ | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| host-crash         | 100   | whole host froze, hard reset, watchdog reset, thermal trip, emergency-mode boot                                                                                                         |
| service-crashloop  | 26    | discordsync (3), browser-history (2), nsfw-classifier (2), pma (2), cv-server (2), bank-sync, pocket-id, monitor365, llama-rag, netbird, clickhouse, homepage, helium, gatus panic, dex |
| desktop-crash      | 13    | niri black screens (4), helium (3), CS2, display watchdog sessions                                                                                                                      |
| mechanism          | 7     | causes without a crash event (OOM forensics, thermal-pstate-guard, memory guard)                                                                                                        |
| not-a-crash-report | 14    | crash incidental                                                                                                                                                                        |
| reference          | 1     | `docs/crash-analysis-2026-08-09.md`                                                                                                                                                     |

### 2.2 Host-crash reports by what they say `[S]`

| Field                                         | Counts (of 100)                                                                                                  |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Kind                                          | autopsy 50, self-review 24, triage 14, fix-wave 9, other 3                                                       |
| Root-cause confidence in the report           | high 37, medium 48, low 6, contested 3, n/a 6                                                                    |
| Reset as stated                               | watchdog 44, "hard reset" 17, unknown 16, owner power 8, thermal trip 7, software CF9 5, emergency mode 1        |
| Family                                        | combined storm + ceiling 25, IO livelock 24, thermal 13, memory cliff 8, zram full 5, emergency mode 3, other 22 |
| Named trigger                                 | agent session 35, autonomous service 22, unknown 22, deploy 11, system timer 8, owner manual 2                   |
| Fix verification at report time               | **live-verified 19**, config-only 23, prescribed-only 37, committed-not-deployed 18, none 3                      |
| "An earlier report or row predicted this cut" | yes 54, no 39, unknown 5, n/a 2                                                                                  |

Motif scan over the same 100 `[S]`: 59 mention a fix that never ran, was inert, undeployed or
dead code; 48 mention a prediction; 30 mention a vacuumed or truncated journal; 25 an
unidentified actor; 11 a forced deploy; 8 a lost evidence bundle.

### 2.3 Numbered freezes (ledger order, local time)

| #   | Cut            | Reset              | Family               | Named trigger                                                       |
| --- | -------------- | ------------------ | -------------------- | ------------------------------------------------------------------- |
| 1   | 08-22 00:27:09 | owner power cut    | zram full            | flm 21.6 GB unevictable, nightly btrbk + nix-gc, ~12 agent sessions |
| 2   | 08-22 05:49:56 | owner power cut    | zram full            | guard stopped the service, not the socket                           |
| 3   | 08-31 16:34    | hard               | IO livelock          | four stacked full-disk readers                                      |
| 4   | 09-14 13:32    | hard               | IO livelock          | llama spin, session DBs on QLC, a stray `find`                      |
| 5   | 09-18 15:27    | hard               | IO livelock          | all-day storm, llama-rag spin, deploy activation                    |
| 6   | 09-18 19:28:11 | hard               | IO livelock          | recovery migration + db heal + ~27 sessions                         |
| 7   | 09-29 09:51    | hard               | scrub loop           | weekly scrub restart loop, 432 trips                                |
| 8   | 10-01 18:27:13 | thermal / hard     | thermal              | D-state wedge, drivers not sourced                                  |
| 9   | 10-01 18:56    | thermal / hard     | thermal              | never-cooled recovery boot                                          |
| 11  | 10-02 10:57:54 | thermal / hard     | thermal              | 3 h at 98–99 °C                                                     |
| 12  | 10-03 14:14    | hard               | thermal              | 27 h clickhouse compile, gopls                                      |
| 13  | 10-04 03:36:03 | thermal            | combined             | tq-agent-pool +155 GB, nix bursts                                   |
| 14  | 10-04 05:07:41 | thermal            | combined             | nix burst, launcher unidentified                                    |
| 15  | 10-04 08:38:22 | thermal            | combined             | soak-unblock session-259, ~120 GB in 21 min                         |
| 16  | 10-05 19:41:16 | thermal            | thermal              | with the pstate guard live                                          |
| 17  | 10-06 15:12:57 | thermal            | thermal              | a deploy against a written `[blocked:user]` gate                    |
| 18  | 10-06 15:41:14 | thermal            | thermal              | 26 m recovery boot                                                  |
| 19  | 10-06 21:08:23 | hard               | IO collapse          | rust-cache USB→USB rsync, first launch                              |
| 20  | 10-06 21:50:42 | hard               | IO collapse          | third migration launch into a build battery                         |
| 21  | 10-07 00:00:59 | hard               | IO livelock          | battery + migration ×4 + midnight nix-gc                            |
| 22  | 10-07 00:58:02 | hard               | IO livelock          | a deploy's ungated validation battery                               |
| 23  | 10-07 01:28:03 | hard               | IO livelock          | healthy memory                                                      |
| 24  | 10-07 02:49:28 | hard               | IO livelock          | healthy memory                                                      |
| 25  | 10-07 08:32:56 | hard               | IO livelock          | tq-pool ~864 GB reads                                               |
| 26  | 10-07 11:03:54 | hard               | IO livelock          | the SIGSTOP-sweep session                                           |
| 27  | 10-11 11:07:59 | hard               | IO livelock          | storm without the memory leg                                        |
| 28  | 10-12 13:04:01 | hard               | combined             | 46 OOM invocations on a chronic storm                               |
| 29  | 10-15 02:17:32 | hard               | combined             | vendorHash-fleet storm                                              |
| 30  | 10-15 03:12:26 | hard               | combined             | owner-manual `btrfs balance` on the critical root                   |
| 31  | 10-18 03:03:38 | watchdog           | combined             | died in guided throttle                                             |
| 32  | 10-20 14:40:30 | hard               | combined             | memory leg, 107 OOM lines                                           |
| 33  | 10-25 04:31:30 | hard               | combined             | 493 trips over 4.5 days                                             |
| 34  | 10-25 22:22:13 | watchdog           | combined             | 637 throttle enters                                                 |
| 35  | 10-26 22:53:58 | watchdog           | combined             | 343 throttle enters                                                 |
| 36  | 10-27 10:03:11 | watchdog           | combined             | +1.3 TB system.slice reads in one window, sdb at 100 %              |
| 37  | 10-28 00:40:38 | watchdog           | combined             | same pair as #36                                                    |
| 38  | 10-30 03:32:02 | watchdog           | combined, memory-led | 38 OOM invocations                                                  |
| 39  | 11-02 11:34:07 | watchdog           | combined             | deploy re-armed the owner-stopped llama-chat                        |
| 40  | 11-02 14:42:00 | watchdog           | combined             | boot-time re-arm + forced deploy 9 min before                       |
| 41  | 11-02 15:16:15 | watchdog           | combined             | 32 m recovery boot                                                  |
| 42  | 11-02 22:07:23 | watchdog           | combined             | clickhouse at 100 % CPU                                             |
| 43  | 11-03 16:16:27 | watchdog           | combined             | memory-led finish                                                   |
| 44  | 11-03 17:39:40 | watchdog           | combined             | recovery boot + parallel build battery                              |
| 45  | 11-03 21:42    | watchdog           | combined             | tq-pool sqlite LIKE scans at 409 MB/s                               |
| 46  | 11-04 19:04:30 | watchdog           | combined             | btrfs delayed-refs reclaim wedge                                    |
| 47  | 11-05 03:03    | watchdog           | combined             | cvagent wave + flm-real SIGABRT crash loop                          |
| 48  | 11-05 03:13    | watchdog           | combined             | six GB-scale cold readers at T+120 s                                |
| 49  | 11-05 20:36:40 | watchdog           | combined             | lint-fleet storm + two forced deploys                               |
| 50  | 11-06 05:56:21 | watchdog           | combined             | all-night multi-session agent storm                                 |
| 51  | 11-07 01:06:21 | owner power cut    | emergency mode       | automount conflict; forced deploy after six refusals                |
| 52  | 11-14 09:20:19 | software CF9       | combined             | morning agent storm; 8 failed deploy attempts                       |
| 53  | 11-14 09:27:13 | watchdog           | combined             | 5 m 55 s recovery boot                                              |
| 54  | 11-14 15:41:18 | owner power button | combined, memory-led | `session-115.scope` 77.9 G, unidentified                            |
| 55  | 11-15 02:24:48 | software CF9       | combined             | never autopsied                                                     |
| 56  | 11-17 15:10:56 | software CF9       | combined             | storm + ceiling                                                     |
| 57  | 11-17 21:01:48 | not pulled         | unknown              | planned reboot versus crash unresolved                              |
| 58  | 11-19 00:08:48 | software CF9       | combined             | io PSI 99 % from 23:55                                              |
| 59  | 11-22 19:52:29 | software CF9       | combined             | unattributed                                                        |
| 60  | 11-22 20:48:35 | watchdog           | combined             | printer-monitor session in-window                                   |
| 61  | 11-23 05:53:51 | software CF9       | combined             | zero session activity                                               |
| 62  | 11-23 21:12:17 | software CF9       | combined             | zero session activity                                               |
| 63  | 11-24 20:44:18 | watchdog           | combined             | `cargo test` into a full rust-cache disk                            |

#10 (2026-10-01 19:08) was defused and is not a cut. #51 and #54 are owner-ended wedges, so
60 of the 62 are autonomous crash ends.

### 2.4 Rate

| Period                                | Crash ends                  | Days | Rate     |
| ------------------------------------- | --------------------------- | ---- | -------- |
| 2026-05-04 → 08-18 (before numbering) | 24                          | 106  | 0.23/day |
| 08-22 → 09-30                         | 3 numbered + 4 un-numbered  | 40   | 0.18/day |
| October                               | 29 numbered + 4 un-numbered | 31   | 1.06/day |
| 11-01 → 11-24                         | 26 numbered                 | 24   | 1.08/day |

The step is on 2026-10-01: the thermal ceiling appears in the record (the #8 bullet's
supersession note dates it to 2026-09-27) and the rate goes from 0.18 to about 1.07 per day.
It has stayed there through seven fix families. The calm gaps are real but short: the longest
is 2026-11-07 → 11-14 (7 d 8 h), then 08-31 → 09-14 (14 d, before the step).

## 3. Findings, ranked

### F1. The ledger misses 11 crash boundaries `[V]`

Three same-day reports numbered their own crash, and the ledger later gave that number to a
different cut, so the same-day event lost its number:

| Cut (local)         | What the same-day source says                                                  | Where                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| 2026-08-24 06:20:52 | "kernel freeze #3 … 4th freeze in 3 days" (ledger #3 is 08-31)                 | `archived/2026-08-24_08-00_crash3-balance-freeze-das-absent-io-diagnosis.md`                                         |
| 2026-09-15 09:32:38 | "Freeze #5 … hard reset" (ledger #5 is 09-18)                                  | `archived/2026-09-15_10-45_freeze-5-diagnosis-io-psi-livelock-13h-storm-git-repair.md`                               |
| 2026-10-04 ~09:32   | "FREEZE #16 CONFIRMED: the 08:39 boot died ~09:32" (ledger #16 is 10-05 19:41) | `2026-10-04_10-50_freeze-15-session-brutal-self-review-…`, and the #16/#17 autopsy's "boot -2 (Oct 04 09:32:34 → …)" |

Five more were never numbered:

| Cut (local)                                   | Boot       | Note                                                                            | Where                                                                                                           |
| --------------------------------------------- | ---------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 2026-09-27 17:54 and ~20:28                   | —          | "BOTH hard cuts … at Tctl ceiling"                                              | #8 bullet in `docs/agents/stability.md`; `2026-10-26_08-19_task-…_stability-batch-sep27-archaeology.md`         |
| 2026-10-10                                    | —          | "Five boots in 6 days (Oct 7 ×2, Oct 10, Oct 11, Oct 12), all hard-cut endings" | `2026-10-12_13-15_freeze-28-crash-diagnosis-session-status.md`                                                  |
| 2026-10-18 00:40:44, plus one more that night | `ee085387` | "daecca67 was the night's third freeze-class boot end"                          | `2026-10-18_00-58_boot-ee085387-thermal-trip-crash-diagnosis-selfreview.md`, `2026-10-18_04-18_status-update-…` |

Two are numbered only in TODO rows and have no ledger row: #57 (`783f2d13`, 2026-11-17
21:01:48) and #58 (`cd60fc6b`, 2026-11-19 00:08:48).

Applied: a table of these 11 now sits in the ledger after the census table (§6).

### F2. Ledger row #46 is wrong about its key evidence `[V]`

The row calls #46 the "first ledger row with MEASURED dead-boot IO attribution (the 18:08:02Z
forensic bundle, captured 56 min pre-death)". The bundle name is UTC (`scripts/io-psi-forensics.sh:47`
`date -u`, unchanged since `3de823e83`), so 18:08:02Z is 19:08:02 CET: 3 m 32 s *after* the
19:04:30 cut. The evidence pull of the same boot was written one minute later
(`docs/status/tasks/2026-11-04_18-09_boot-fe8f7548-evidence-pull.md`). The bundle describes the
recovery boot `91b4a3a2`, not the dead boot. The #48 and #50 rows convert the same stamp
correctly. The row is corrected; the source report (`2026-11-04_19-30_freeze-46-…`) is left as
history.

### F3. "Panic-reboot" is a label, not a finding; kdump has never captured anything `[V]`

- The ledger classes #52, #55, #56, #58, #59, #61 and #62 as "software wrote 0x6 to 0xCF9 =
kernel panic-reboot path". No cut of this class ever produced panic text, a pstore record or a
  vmcore.
- The same register value is what *any* software restart leaves on this board. The #59 report
  itself says an owner-forced `reboot -f` fits equally. The repo has no code that reboots the
  host except `kdump-save` (capture boot only); `kernel.sysrq = 1` is enabled.
- The crash kernel was not loaded before 2026-11-22: boot `e5cad2ec` (the #59 boot) still ran
  with a 128 MB reservation and logged `kexec_file_load failed: Cannot assign requested
  address` at 2026-11-19 00:09:46. From boot `69ee350d` (2026-11-22 19:53:18) the reservation
  is 512 MB, no failure is logged, and the 05:33:49 kernel report in boot `3aa71817` prints
  `Kdump: loaded`. Live now: `/sys/kernel/kexec_crash_loaded = 1`.
- #61 and #62 were CF9 cuts in those armed boots. A real `panic()` would have kexec'ed into
  the capture kernel. There is no capture boot in the boot index, `kdump-save.service` has
  zero journal lines since 2026-11-19, and `/var/crash` is empty (created 2026-11-19 14:44).

So either the capture path fails end to end, or these resets were not kernel panics. Both
matter: seven cuts carry a mechanism label that has never been confirmed. Existing row "Make
kdump capture one cut" is updated with this (§f.1).

### F4. A kernel warning no report mentions precedes two cuts `[V]`

`WARNING: mm/page_alloc.c:4835 at __alloc_frozen_pages_noprof`, CPU `kswapd0` (line 4816 on
7.3.3), with this stack:

```
kswapd → balance_pgdat → shrink_node → shrink_slab → super_cache_scan → prune_dcache_sb
→ dentry_kill → dput → sync_lazytime → ext4_dirty_inode → jbd2__journal_start
→ start_this_handle → ext4_reserve_inode_write → ext4_get_inode_loc
→ __getblk_slow → __filemap_get_folio_mpol → folio_alloc → alloc_pages_mpol
```

Memory reclaim on one ext4 filesystem enters the ext4 journal and then asks the page
allocator for a buffer. The only ext4 filesystem on the host is `/mnt/buildcache`
(`/dev/sdb1`, `rw,noatime,lazytime,commit=120,data=writeback`, the USB buildcache SSD).

| Dead boot                                                  | Freeze                  | Warning time        | Before the cut |
| ---------------------------------------------------------- | ----------------------- | ------------------- | -------------- |
| `cd60fc6b`                                                 | #58                     | 2026-11-18 10:46:14 | 13.4 h         |
| `69ee350d`                                                 | #60                     | 2026-11-22 20:40:09 | 8.5 min        |
| `3aa71817`                                                 | #61                     | 2026-11-23 05:33:49 | 20 min         |
| `7096665b`, `783f2d13`, `e5cad2ec`, `a95832c5`, `27ec3ede` | #56, #57, #59, #62, #63 | none                |                |

Zero mentions anywhere in the repo (`grep -r '__alloc_frozen_pages\|page_alloc.c'` over docs
and TODO). It is a marker, not a proven cause. It appeared 8.5 and 20 minutes ahead of two
cuts, which is longer than any alert that exists today. Queued as §f.2.

### F5. Fixes land, then turn out not to have run `[S]`, `[V]` for the examples

- Only 19 of 100 host-crash reports show a live-verified fix at report time; 55 are
  prescribed-only or committed-not-deployed.
- 59 of 100 contain a statement that an earlier fix never ran, was inert, was undeployed, or
  was dead code. Checked examples:
  - `2026-10-12_13-15_freeze-28-…`: "freeze-6 rule (b) never landed (six weeks stale)".
  - `2026-10-07_00-15_freeze-21-…` harvest log: "OBSOLETE f.3 (no-heavy-builds gate removed
    by owner 2026-10-14)".
  - `2026-08-31` response: the scrub deferral guard was eval-verified only; the ledger's #7
    bullet later reports it as dead code.
- `[R]` The no-heavy-builds admission gate that every autopsy #16–#22 prescribed was removed
  by the owner on 2026-10-14. The same harvest log marks the migrate entry gate and the
  midnight-job gate DONE, and the reader found no evidence for either in the file.
- One closed loop, verified in tree: deploy.sh now runs "ENTRY gates: pressure + guard-trip
  recency (freeze #22 — BEFORE the validation battery)" (`scripts/deploy.sh:372`).

### F6. Cuts were predicted, then happened `[S]`, `[R]`

54 of 100 reports say an earlier report or row predicted the cut. The clearest chain is the
thermal family: #8's own session warned at 18:51 and #9 cut at 18:56; the #12 report named
"freeze #13 bait" and the URGENT cooling row was marked "BAIT TAKEN" 13 h later; #13's report
predicted #14 (88 min), #14's predicted #15, #15's predicted the 10-04 09:32 cut. Every one of
those reports also carried a written "NO heavy builds until the cooling inspection" gate, and
the readers found the autopsying sessions themselves launched builds during it.

The warnings were prose. Nothing enforced them, and the one admission gate that could was
later removed (F5).

### F7. Evidence is lost faster than it is pulled `[V]`

- The journal now starts at boot `7096665b` (2026-11-16 10:20:01), at 7 G of the 8 G cap.
- #55's boot `b8f909cd` is already vacuumed. Row "Freeze #55 full autopsy from aging journal
  evidence" can no longer be met from the journal.
- Four more dead boots have reports but no committed evidence pull: `7096665b` (#56),
  `783f2d13` (#57), `cd60fc6b` (#58), `e5cad2ec` (#59). All four are still in the boot index.
- `[S]` 30 of 100 host-crash reports mention a vacuumed or truncated journal and 8 a lost
  bundle. `[R]` Bundles live under `/var/tmp`, which does not survive a reboot (#50's pre-death
  bundle and ~49 siblings vanished; #52's was wiped at the reboot).

The pulls were not run in this session: each dump is a multi-GB journal read and write, and
the box was not calm (see the live-state table).

### F8. Recurring process faults `[S]`, `[R]`

- **Forced deploys:** 11 reports mention `DEPLOY_FORCE_PRESSURE=1` or a forced deploy. #40
  died 9 min after one; #49 had two; #51 had one after six refusals.
- **Unidentified launchers:** 25 of 100. Who ran the rust-cache migration four times (#19–#21),
  deploy #2 (#22), the #14 death-minute nix burst and #54's 77.9 G session is never named.
- **Numbers that disagree inside or between reports:** ledger vs report guard-action counts
  (#28: five executed vs three; #26: 467 s vs 478 s); "seven cuts (#8/#9/#11–#17)" lists
  nine; the #49 incident note calls the 20:02 deploy "blocked by storm gate … the RIGHT call"
  and has zero mentions of the forced flag, against its own autopsy.
- **Empty reads taken as evidence:** `journalctl -b <8-char id>` (10-18), a silently broken
  `rg -o` (10-28), `pstore empty` that was permission-denied (#8–#15), `kill` reporting success
  without executing (10-15). Most are now rules in `AGENTS.md`.
- **Fixes that caused the next problem:** the 08-11 crash-loop fix `a1223f22` was never
  deployed, and its start-limit keys sat in `[Service]`, where systemd 261+ ignores them, so
  browser-history-agent restarted every ~18 s without limit `[R]`; the ledger names the udev
  `hdparm` rule `d57c1210` as the root cause of the 2026-08-22 DAS USB drop; the 06-23 deploy
  caused an emergency-mode boot (`discard=async` on ext4).

### F9. Before numbering, the same disease `[R]`

2026-05 → 2026-08: 24 evo-x2 crash ends, four different watchdog root causes in nine days
(08-03 missing slice memory cap, 08-04 QLC SLC cache exhaustion, 08-09/10 pma page-cache
death loop, 08-11 browser-history crash loop) that contradict each other. The user-slice
memory cap prescribed on 05-25 was still absent on 06-19. The oldest "host-crash" report
(2026-02-09, kernel panic) is a MacBook, not evo-x2.

## 4. Why the rate is flat, in the reports' own terms

Each era's top fix answered the previous era's launcher: the flm socket loop, the scrub
restart loop, guided throttling, deploy entry gates, the llama-chat retirement, the calm gate,
the 90 s watchdog. The next storm came from a launcher that did not exist yet: a migration
rsync, a build battery, a forced deploy, a boot-time re-arm timer, a 409 MB/s sqlite scan, a
lint fleet, `cargo test` into a full disk.

Three things stayed constant through all of it:

1. **A standing thermal ceiling.** `Tctl 99.1 °C at load ~20 with no build running` (#12,
   2026-10-03). 98 °C at load 22 tonight. Physical remediation is waived by owner verdict
   (2026-11-14), so this is a permanent constraint, which makes every extra all-core job a
   thermal event.
2. **Unbounded concurrent agent load.** 35 of 100 reports name an agent session as the
   trigger and 11 a deploy. The concurrency-cap row has been `[decision]` since 2026-10-25.
3. **Recovery boots re-arm the load.** Boot-time re-arms and cold readers produced six
   consecutive recovery-boot deaths (#40–#45). The calm gate refused three re-arms on #53's
   boot and the boot died 5 m 55 s in anyway.

Against that, the guard has been structurally powerless since #50: every trip from #12483 to
#13081 logged "NO eligible headless tree matched" (#50, #52, #60–#63 rows).

What the record credits as working: the reset-reason decode (2026-10-27 on) ended the thermal
trip versus watchdog confusion; the evidence-pull and crash-triage scripts with full-count
censuses; deploy entry gates before the validation battery; the PSI gate refusing the tq pool
all through #47's boot; the 7-day calm gap of 2026-11-07 → 11-14.

## 5. Follow-up drift

`scripts/check-todo-system.sh` at 2026-11-25 00:05: `OK: TODO queue/library structure clean`,
`WARN: 133 queue/library entry drift(s)`, `WARN: 102 unharvested §f-bearing report(s)`. The two
WARNs predate this review. Six of the 102 are crash reports:

| Report                                                                         | Open follow-ups the gate sees no surface for                                                                                                |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `2026-11-14_16-17_crash-loop-fix-wave-brutal-selfreview.md`                    | deploy the wave in a calm window + verification battery; attribute x2dx2 ×14 and cvagent ×4 restarts; crash-loop alert leg; push 26 commits |
| `2026-11-14_16-55_psi-band-80-enrollment-storm-reboot-forensics.md`            | band 80 + enrollment deploy not fired; cvagent P0 fix; shadow-bundle sweep ruling                                                           |
| `2026-11-14_18-30_crash-loop-followup-brutal-selfreview-status.md`             | verification battery 4/4 unrun; runner loop fix; 28+ commits unpushed                                                                       |
| `2026-11-15_09-35_night-deploy-marathon-gens1008-1011.md`                      | immich converger deeper verify; it also records no freeze although #55 cut at 02:24:48 mid-session                                          |
| `2026-11-17_17-44_freeze-56-fix-wave-closeout-session-status.md`               | deploy + proof battery; kdump observability; boot-evidence pull for `7096665b`; storm-admission policy                                      |
| `2026-11-24_22-10_rust-cache-wave-continuation-evidence-census-self-review.md` | deploy the wave; CH ingest-stall forensics; guard no-match era; concurrent-session load guard                                               |

Stale rows found: "kdump dump-dir missing: /var/crash does not exist" (the directory has
existed since 2026-11-19 14:44) and "Freeze #55 full autopsy from aging journal evidence"
(the boot is vacuumed). Both annotated, neither ticked (§6).

## 6. Corrections applied in this session (living docs only)

Historical reports were not edited.

1. `docs/agents/stability.md` #46 row: bundle time corrected to 3 m 32 s after the cut, in the
   recovery boot.
2. `docs/agents/stability.md` #59 row: boot id `—` → `e5cad2ec` (journal index: 2026-11-19
   00:09:35 → 2026-11-22 19:52:29, 91.7 h).
3. `docs/agents/stability.md`: new table "Un-numbered and un-ledgered crash boundaries" after
   the census table, plus a count note on the boot-cadence headline (37 sums the cluster table
   through #48 on 11-05; 36 cuts fall inside Oct 1 → Nov 3; neither counts the un-numbered).
4. `docs/todo/stability.md` + `TODO_LIST.md`: rows updated and added as §f.
5. `docs/todo/stability.md`: two stale `[blocked:user]` rows annotated.

## a) FULLY DONE (verified this session)

1. Corpus census: 161 files by a stated rule, every path exists, listed in the appendix.
2. All 161 read completely; 161/161 extraction blocks verified by script.
3. Tallies of §2.2 produced by script from the extractions.
4. Live journal checks of F2, F3, F4, F7 (reset reasons, crash-kernel load lines, `kdump-save`
   unit history, per-boot warning counts, boot index, journal usage).
5. Ledger corrections 1–3 and TODO edits 4–5, re-read after edit; TODO gate re-run after them
   (`OK`, WARN counts unchanged at 133 and 102).
6. Scoped formatter on the four touched files: `nix fmt -- --fail-on-change <files>` reports
   `formatted 4 files (0 changed)` on the 01:10 retry. The 01:05 attempt failed before
   formatting on another session's in-flight `tracking-papers` flake input (infra-follows audit),
   which had landed by the retry.

## b) PARTIALLY DONE

1. Ledger-vs-report reconciliation: done for dates, boot ids, numbering and reset classes.
   Trip counts and per-freeze trigger wording were not re-derived line by line.
2. Follow-up drift: determined by the existing gate, not by reading every open item.

## c) NOT STARTED

1. Evidence pulls for the four retained dead boots (F7): needs a calm window.
2. Re-labelling #34–#37 trigger rows in §2.3 with more than the ledger's own words.
3. Annotating the same-day mis-numbered reports (#3, #5, #16) in place: owner call (§g.2).

## d) Honesty ledger

1. The readers' `[R]` statements are extraction, not my reading. I spot-checked eleven against
   the source files: ten held, one did not (the "WDT signature known on 10-12" reading of the
   freeze-38 self-review, dropped).
2. The §2.2 counts are first-token and keyword scans of free-text fields. "Prescribed-only"
   versus "config-only" is the reader's judgement call.
3. The "predicted" count treats a self-review's repeat of its autopsy's prediction as another
   yes. The per-cut view is smaller but the chains in F6 are individually sourced.
4. Three readers hit zai rate limits; one batch was recovered from a file it had already
   written, so its 300-word summary is missing. Nothing else was lost.
5. This review ran three extra agent sessions on a box whose reports name agent sessions as
   the top trigger. They read files only, but the count is part of the problem being reviewed.
6. `docs/services/crush.md`, `docs/services/tq.md`, `flake.lock` and two tq files changed in the
   tree during the session. They are not mine and were not touched.
7. Nothing here is committed by me. The auto-commit daemon will sweep the four files.

## e) What we should improve (mechanisms, not effort)

1. **A cut gets its number when its first report is written, and the ledger gets the row in
   the same edit.** Three number collisions and nine silent drops came from reports written
   without touching the ledger.
2. **A fix is not "done" until a later report observes it working.** The harvest-log "DONE"
   lines that the next freeze contradicts are the single most repeated failure in the corpus.
3. **A written warning needs a gate or it is decoration.** "No heavy builds" was written
   before four consecutive cuts.
4. **Pull the boot at triage, not later.** Five dead boots since #55 have no pull and one is
   gone.
5. **Name the launcher in every autopsy.** A quarter of reports end with "actor unidentified".
6. **Test the forensic tooling on a good day.** kdump has been "armed" for three months and
   has never been proven to capture.

## f) NEXT (session-harvested; every row cites this report)

| #   | Row                                                                                                                                                                                           | Surface                                   |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| 1   | Make kdump capture one cut (updated: armed since 2026-11-22 19:53, #61/#62 no capture, controlled-panic test, CF9 label caveat)                                                               | `TODO_LIST.md` + `docs/todo/stability.md` |
| 2   | NEW Alert on and decode the kswapd0 page-allocator warning                                                                                                                                    | `TODO_LIST.md` + `docs/todo/stability.md` |
| 3   | Freeze-ledger backfill (updated: four un-pulled boots still indexed, journal at 7 G/8 G)                                                                                                      | `TODO_LIST.md` + `docs/todo/stability.md` |
| 4   | NEW `[decision]` Number the un-numbered crash boundaries or rule them permanently un-numbered; annotate #3/#5/#16 in place                                                                    | `TODO_LIST.md` + `docs/todo/stability.md` |
| 5   | Two stale `[blocked:user]` rows annotated (#55 autopsy, kdump dump-dir)                                                                                                                       | `docs/todo/stability.md` only             |
| 6   | Six unharvested crash reports: deliberately not harvested here. The standing sweep rows ("Run a dedicated unharvested-§f-report sweep", "Close the unharvested-backlog count") own the class. | existing rows                             |
| 7   | Parallel-agent-session concurrency cap `[decision]`: not re-rowed. §4 and §2.2 are the evidence it was waiting for.                                                                           | `docs/todo/stability.md:17`               |

## g) Owner questions

1. **May a controlled kernel panic be triggered in a calm window** (`echo c | sudo tee /proc/sysrq-trigger`)? It is the only way to tell whether kdump works or whether #61/#62 were panics at all.
2. **Should the nine un-numbered cuts get suffix numbers** (for example #15b for 2026-10-04 09:32), or stay recorded as un-numbered? Should the three same-day reports be annotated in place?
3. **Should `lazytime` stay on `/mnt/buildcache`?** The new warning's stack runs through ext4 lazytime expiry under reclaim. Dropping it is a cheap A/B if you accept more inode writes.
4. **Is the concurrency cap still a decision you want to hold?** 46 of 100 host-crash reports name an agent session or a deploy as the trigger, and tonight's recovery boot ran 37 `crush` processes at Tctl 98–99 °C.
5. **Who or what can restart this host without a journal trace?** Nothing in the repo can. If you used SysRq-B or a forced reboot on 11-22, 11-23 (twice) or the other four CF9 nights, #52/#55/#56/#58/#59/#61/#62 are not panics and the ledger should say so.

## References

- Ledger: `docs/agents/stability.md` (bullets lines 18–52, census table lines 86–118).
- Scripts used read-only: `scripts/check-todo-system.sh`, `scripts/io-psi-forensics.sh` (read),
  `scripts/pre-vacuum-evidence-gate.sh` (read).
- Config checked: `platforms/nixos/system/boot.nix` (`kernel.panic`, `kernel.sysrq`,
  `crashDump.reservedMemory`, `kdump-save`, watchdogd timeout), `scripts/deploy.sh` entry gates.
- Session artifacts (not in repo): `~/.cache/crash-review/` (`corpus_final.txt`, `batches/`,
  `extract/B01–B13.md`, `merged_all.md`, `stats_all.txt`, `todo-gate.log`, `findings.md`).
- TODO gate after the edits: `OK: TODO queue/library structure clean`, `WARN: 133 queue/library
  entry drift(s)`, `WARN: 102 unharvested §f-bearing report(s)`, identical to the pre-edit run.

## Appendix: corpus (161 files, script-generated from the corpus rule)

### docs/status top level (89)

```
2026-09-18_19-45_freeze-6-io-livelock-crash-recovery-readers-crush-migration-db-heal.md
2026-09-18_20-06_freeze-6-diagnosis-session-status-self-review.md
2026-09-29_10-09_freeze-7-scrub-restart-loop-root-cause.md
2026-09-29_11-34_gatus-panic-notification-storm-incident.md
2026-09-30_07-47_p0-fixes-first-deploys-acme-dns-recovery.md
2026-10-01_18-49_freeze-8-thermal-trip-forensics-session-status.md
2026-10-01_19-21_nvme-exoneration-and-corrections-session-status.md
2026-10-01_21-04_caddy-cutover-unchanged-crash-impact-fod-shims-bump-fallout.md
2026-10-02_11-10_freeze-11-thermal-ceiling-instant-cut-forensics.md
2026-10-03_14-23_freeze-12-autopsy-thermal-leading-livelock-competing.md
2026-10-04_03-50_freeze-13-autopsy-thermal-ceiling-instant-cut-under-chronic-io-storm.md
2026-10-04_05-22_freeze-14-autopsy-predicted-second-thermal-cut-inside-90-minutes.md
2026-10-04_06-39_thermal-pstate-guard-implementation-self-review.md
2026-10-04_09-15_freeze-15-autopsy-third-overnight-thermal-cut-death-minute-container-identified.md
2026-10-04_10-50_freeze-15-session-brutal-self-review-comprehensive-status.md
2026-10-06_15-30_freeze-16-17-autopsy-guided-throttle-live-crash-family-unbroken.md
2026-10-06_15-35_bank-sync-vendorhash-fixed-deploy-gated-freeze17-self-review.md
2026-10-06_16-02_freeze-18-autopsy-predicted-cut-runner-failloop-gated.md
2026-10-06_16-19_freeze-18-response-session-brutal-self-review-status.md
2026-10-06_19-30_netbird-client-first-deploy-crash-managementurl-fragment-fix.md
2026-10-06_21-25_freeze-19-autopsy-rust-cache-migration-usb-to-usb-rsync-storm-live-containment.md
2026-10-06_21-36_freeze-19-autopsy-session-brutal-self-review-status.md
2026-10-06_22-18_freeze-20-autopsy-third-migration-launch-into-live-build-battery.md
2026-10-06_22-33_freeze-20-review-session-brutal-self-review-status.md
2026-10-07_00-15_freeze-21-autopsy-battery-never-stopped-migration-run4-midnight-nix-gc-terminal.md
2026-10-07_01-08_freeze-22-autopsy-deploy-validation-ungated-tq-battery-terminal.md
2026-10-07_02-43_tq-done-preflight-crashloop-fix-committed-deploy-deferred.md
2026-10-07_02-59_freeze-24-live-autopsy-io-livelock-pinned-guard-ineffective.md
2026-10-07_03-02_browser-history-fix-verified-lockout-and-freeze24-context.md
2026-10-07_09-00_freeze-25-autopsy-guard-action-executed-ineffective-tq-864gb-recovery-storm-contained.md
2026-10-07_09-21_freeze-25-followup-respawn-source-macbook-owner-ruling-storm-drained.md
2026-10-07_11-26_freeze-26-autopsy-sweeps-revoked-license-pty-breakage.md
2026-10-07_16-17_fastflowlm-crash-trigger-gocommit-timeout-fix.md
2026-10-10_07-31_bun-memory-watchdog-16gib-kill-guard.md
2026-10-12_13-15_freeze-28-crash-diagnosis-session-status.md
2026-10-13_01-45_window-closeout-five-task-roundup.md
2026-10-13_15-13_bank-sync-rollback-and-deploy-unblock.md
2026-10-15_03-24_freeze-29-30-crash-diagnosis.md
2026-10-18_00-58_boot-ee085387-thermal-trip-crash-diagnosis-selfreview.md
2026-10-18_04-18_status-update-pre-deploy-unblock-boot-path-defects.md
2026-10-25_04-57_freeze-31-33-crash-diagnosis.md
2026-10-25_05-48_freeze-33-autopsy-session-brutal-self-review-full-status.md
2026-10-25_06-15_nsfw-classifier-typed-nil-crash-loop-fix-full-status.md
2026-10-25_06-21_nsfw-crash-loop-fix-session-status.md
2026-10-27_10-38_freeze-34-36-watchdog-hard-cuts-diagnosis.md
2026-10-27_11-37_freeze-autopsy-status-and-brutal-self-review.md
2026-10-28_00-58_watchdog-double-crash-diagnosis-live-recovery-storm-status.md
2026-10-30_03-40_freeze-38-watchdog-crash-forensics-self-review.md
2026-11-02_11-58_freeze-39-wdt-autopsy-deploy-rearm-triple-coldload-fleet-battery.md
2026-11-02_12-20_freeze-39-autopsy-session-brutal-self-review.md
2026-11-02_14-58_freeze-40-wdt-autopsy-never-contained-recovery-boot-forced-deploy.md
2026-11-02_15-04_memory-emergency-guard-io-restore-gate-session.md
2026-11-02_15-06_freeze-40-response-session-full-status-and-self-review.md
2026-11-02_17-10_window-closeout-five-task-window-20261030-1102.md
2026-11-03_16-34_freeze-41-crash-triage-self-review.md
2026-11-03_18-20_freeze-41-44-containment-llama-chat-retired.md
2026-11-03_18-40_freeze-41-44-containment-brutal-self-review.md
2026-11-03_23-23_freeze-45-crash-triage-tq-pool-brake-live-storm-session.md
2026-11-04_19-30_freeze-46-crash-triage-self-review.md
2026-11-05_04-15_watchdog-incident-tmpfiles-first-wins-overnight-execution-status.md
2026-11-05_04-46_freeze-47-48-calm-gate-wiring.md
2026-11-05_21-00_freeze-49-wdt-autopsy-forced-deploy-into-storm.md
2026-11-05_21-03_freeze-49-fix-session-brutal-self-review.md
2026-11-05_go-build-storm-freeze-49-incident-note.md
2026-11-06_01-05_sev1-cvserver-crashloop-nilguard-landed-textfile-pending.md
2026-11-06_01-08_sev1-cvsession-full-status-and-self-review.md
2026-11-06_06-44_brutal-self-review-freeze50-triage-session.md
2026-11-06_06-45_freeze-50-triage-ere-oncalendar-fixes-bundle-vanish-status.md
2026-11-07_01-25_freeze-51-emergency-mode-automount-activation-conflict-owner-power-cut.md
2026-11-07_01-36_freeze-51-triage-session-brutal-self-review.md
2026-11-14_10-12_freeze-52-53-thermal-ceiling-morning-storm-double-cut.md
2026-11-14_11-31_freeze-52-53-session-self-review-status.md
2026-11-14_16-06_freeze-54-memory-cliff-session-hog-oomd-desktop-kill-spiral.md
2026-11-14_16-17_crash-loop-fix-wave-brutal-selfreview.md
2026-11-14_16-20_crash-loop-fix-wave-status.md
2026-11-14_16-26_freeze-54-session-brutal-self-review-status.md
2026-11-14_16-55_psi-band-80-enrollment-storm-reboot-forensics.md
2026-11-14_18-30_crash-loop-followup-brutal-selfreview-status.md
2026-11-15_09-35_night-deploy-marathon-gens1008-1011.md
2026-11-17_15-24_freeze-56-crash-diagnosis-session-self-review.md
2026-11-17_17-44_freeze-56-fix-wave-closeout-session-status.md
2026-11-19_01-04_boot-cd60fc6b-crash-diagnosis-self-review-status.md
2026-11-22_19-47_owner-halt-resume-status-deaf-trigger-untested-upstream-edits-red-reboot-gate.md
2026-11-22_20-04_freeze-59-panic-reboot-autopsy-zero-new-fs-damage-journal-serve-startlimit.md
2026-11-24_05-21_health-check-sweep-40-chronic-red-audiblesync-fix-notification-dedup.md
2026-11-24_21-42_rust-cache-freeze-fix-wave-closeout-self-review.md
2026-11-24_21-58_rust-cache-full-four-freezes-cargo-gate-usage-triggered-gc.md
2026-11-24_22-10_rust-cache-wave-continuation-evidence-census-self-review.md
2026-11-24_22-35_zombie-niri-black-screen-live-recovery-full-status.md
```

### docs/status/archived (68)

```
2026-02-09_01-38_KERNEL-PANIC-INVESTIGATION-AND-ZFS-REMOVAL.md
2026-03-26_20-53_EMERGENCY-STATUS-REPORT.md
2026-04-11_17-31_CS2-CRASH-FIX-GAMING.md
2026-04-20_07-32_GPU-CRASH-INCIDENT-AND-SERVICE-FIXES.md
2026-05-04_06-21_SYSTEMD-WATCHDOG-MASSACRE-FIX.md
2026-05-04_22-53_CRASH-RECOVERY-DEFENSE-IN-DEPTH.md
2026-05-06_07-54_SESSION-38-WATCHDOG-MANIFEST-HEALTHCHECK-SOPS-DEDUP.md
2026-05-10_18-19_SESSION-58-WIFI-MPTCP-DNS-PANIC-HAGGELE.md
2026-05-10_21-13_SESSION-61-CRASH-FORENSICS-GPU-BUDGET-RESILIENCE.md
2026-05-11_10-58_SESSION-65-FULL-COMPREHENSIVE-STATUS-GPU-DEFENSE-DEPLOYED.md
2026-05-11_23-35_SESSION-78-GPU-CRASH-DIAGNOSIS-FULL-STATUS.md
2026-05-16_23-30_SESSION-23-DISPLAY-WATCHDOG-SELF-HEALING-FULL-STATUS.md
2026-05-19_20-14_session-60-forgejo-watchdogsec-fix-comprehensive-audit.md
2026-05-20_11-41_session-65-tmp-disk-exhaustion-niri-crash-diagnosis.md
2026-05-24_00-55_SESSION-82-WATCHDOG-NO-REBOOT-GO-REPO-CLEANUP.md
2026-05-24_04-57_SESSION-82-WATCHDOG-VENDOR-HASH-CASCADE-BOOT-SUCCESS.md
2026-05-25_02-32_SESSION-89-POST-CRASH-FORENSICS-OOM-FIX.md
2026-06-03_11-13_POST-CRASH-FORENSICS-RESILIENCE.md
2026-06-10_19-18_SESSION-128-POST-GPU-CRASH-CASCADE-FIX-OVERVIEW-BUILD.md
2026-06-23_03-25_oom-forensics-memory-strategy-disk-crisis.md
2026-06-23_04-08_root-disk-emergency-mglru-committed-deploy-blocked.md
2026-06-23_18-15_EMERGENCY-SHELL-RECOVERY-DOCKER-REBUILD-PREVENTION.md
2026-07-14_14-35_btrfs-enospc-crash-boot-diagnosis.md
2026-07-22_03-49_ssh-timeout-wdt-crash-diagnosis-and-bun-memory-limiter.md
2026-07-22_19-16_helium-display-switch-crash-diagnosis-and-autostart.md
2026-07-24_06-25_helium-empty-window-crash-loop-fix.md
2026-07-27_16-41_homepage-bookmark-schema-crash-fix-and-lessons.md
2026-07-28_21-21_discordsync-crash-loop-diagnosis-and-fix.md
2026-07-29_09-24_discordsync-turso-403-crash-loop-monitoring-self-review.md
2026-07-29_16-58_monitor365-cpu-burn-and-server-crash-fix-session.md
2026-08-03_03-17_pocket-id-francis-crash-loop-fix.md
2026-08-03_22-31_wdt-crash-user-1000-slice-memory-cap-broken.md
2026-08-03_23-06_wdt-crash-diagnosis-build-blocked-nothing-deployed.md
2026-08-04_00-03_crash-recovery-session-brutal-honest-review.md
2026-08-04_00-32_display-watchdog-login-screen-false-positive-fix.md
2026-08-04_01-20_crash-recovery-deploy-results-and-issues.md
2026-08-04_21-59_monitor365-pool-deadlock-watchdog-fix.md
2026-08-04_23-51_qlc-slc-cache-exhaustion-crash-root-cause.md
2026-08-05_00-50_bug-fixes-auto-git-race-and-live-io-emergency.md
2026-08-09_11-40_pma-death-loop-crash-analysis-and-fix.md
2026-08-10_18-49_pma-page-cache-thrash-crash-fix.md
2026-08-11_14-12_browser-history-crash-loop-wdt.md
2026-08-11_14-49_browser-history-crash-loop-wdt-full-status.md
2026-08-11_23-28_wdt-crash-postmortem-deploy-blockers.md
2026-08-12_00-45_wdt-crash-startlimitbug-deploy-success.md
2026-08-12_10-20_comprehensive-session-review.md
2026-08-13_01-50_clickhouse-merge-tree-sanity-check-fix.md
2026-08-14_18-29_buildcache-ssd-setup-status.md
2026-08-15_01-34_monitor-aware-desktop-deployed.md
2026-08-18_02-27_discordsync-di-crash-loop-outage-fix.md
2026-08-18_08-15_niri-black-screen-root-cause-and-fix.md
2026-08-18_12-37_niri-black-screen-self-review.md
2026-08-18_13-51_black-screen-followup-execution-self-review.md
2026-08-18_14-52_black-screen-followup-p1-follow-through.md
2026-08-19_19-15_llama-rag-model-provisioning-fix.md
2026-08-22_06-05_crash-forensics-nic-vanish-memory-guard-crash2.md
2026-08-22_06-12_quick-wins-deploys-crash-self-review.md
2026-08-22_06-20_kernel-freeze-2-guard-feedback-loop-psi-blindspot.md
2026-08-22_06-24_self-review-freeze2-guard-hardening.md
2026-08-22_06-41_STATUS-freeze2-guard-hardening-complete.md
2026-08-24_08-00_crash3-balance-freeze-das-absent-io-diagnosis.md
2026-08-31_16-50_crash-forensics-freeze-incident-3.md
2026-08-31_17-48_freeze-incident-3-response-self-review.md
2026-09-14_02-04_task-000001a09d2b6d9f9b5948caf0c822613521.md
2026-09-14_11-19_first-real-reboot-postboot-flm-revert-llama-regression-io-storm.md
2026-09-14_13-54_freeze-4-diagnosis-llama-rearm-io-storm.md
2026-09-15_10-45_freeze-5-diagnosis-io-psi-livelock-13h-storm-git-repair.md
2026-09-18_15-50_freeze-5-llama-spin-io-storm-mid-deploy.md
```

### Outside docs/status (4)

```
docs/archive/crash-analysis-2026-06-15.md
docs/archive/crash-analysis-2026-08-11.md
docs/crash-analysis-2026-06-26.md
docs/crash-analysis-2026-08-09.md
```
