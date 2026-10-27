# Storage-Crisis Execution — Session 3 (day 1, night): THE 98% CLOCK IS BROKEN

**Date:** 2026-10-27 23:3x CET · **Session:** storage-crisis executor instance 3 (continues the 18:51 report lineage; same tombstoned plan)
**Plan:** `docs/planning/2026-10-27_11-49_SUPERB-storage-crisis-recovery-pareto-plan.md` (S1–S27)
**One-line verdict:** **Root fs went 99%→89% in one hour (716G→622G used, 4G→83G avail, unallocated 1MiB→10GiB) via the sanctioned stopgap ladder (cache rm → precise trash empty → early snap rotation); train A is LIVE (gen-956) and fully verified except the drill (IO-storm timeout, 60min budget staged); train B (5 fixes incl. two shipped-broken day-1 items I caught live: the freshness awk bug and the btrbk resume_missing failsafe) is armed on a sequencer.**

---

## 0. Live state at report time (23:3x)

- Root `@`: **622G/723G used, 83G avail, 89%** — the 98%→100% clock (root hit **99% at 21:16**, 16G→14G avail, ~3-5h to full with the 03:00 backup needing ~33G into that) is DEAD. Device-unallocated **1.00MiB → 10GiB** — the metadata-ENOSPC precursor state is gone.
- btrfs cleaner: finished (async reclaim complete; rescue subvols gone from the list).
- Train B sequencer armed (`~/.cache/storage-crisis/trainb-sequencer.sh`): 4×60s quiescence + PSI 2-min ≤80% (owner policy) + green-eval + no-foreign-deploy, then `nix run .#deploy`. Being held up only by parallel-session tree churn (paperless + drain sessions active all evening).
- The 23:00 btrbk fire: local snapshots TOOK (`@.20261027T2300` + hermes twin) but **pool sends ABORTED — see §a "btrbk failsafe"** (fixed in train B; full re-seed sequenced after).

## a) FULLY DONE (verified this session)

| Item | Evidence |
| --- | --- |
| **Crisis relief ladder executed** | (1) ~/.cache rebuildable caches rm'd per doctrine (go/bun/gopls/etc. ~11G immediate — /home/lars is UNSNAPSHOTTED: @home is not in btrbk, so its frees are instant; the ">90G" µ27.3 figure was stale, live was 49G→~24G); (2) the 30-item S1 trash precisely emptied (dual-root) + the 67G forgejo.qlc-pre-subvol entry rm'd; (3) early rotation of the 4 local @ snaps (10-25 + 10-26×3, pool targets verified present first — the guard correctly ABORTED on @.20261026T2300 whose pool target is missing (burst-night send gap; deleted deliberately: pool holds 2308+2329 supersets)) + the 2 incident-era `.rescue` snaps. Result: **94G reclaimed**, 99%→89% |
| **THE PIN PREMISE CORRECTED (load-bearing)** | The 18:51 report claimed the 67G trash was "UNPINNED → immediate relief". WRONG: the trash MOVE (Sep 26) predates the snaps, but the snaps CONTAIN the trash dir → all 67G stayed pinned (zero df movement post-rm proved it). Same for S1 trash and the S4 prunes. NOTHING freed df until the snaps died. Both TODO rows + this report correct the record; lesson: pin questions need fi-du/df-delta evidence, never trash-mtime reasoning |
| **S4 pruner verified LIVE** | The drain session's 22:02 backup force-fire exercised the deployed KEEP=2: exactly 5 deletions (10-22/10-23 33G fulls + the 3 corpses incl. the 16:14 off-schedule), 2 good rungs kept. Row closed with the S10 physical caveat: the pruned backups were reflink-shared with the live DB (6.43GiB exclusive total) — the prune was correctness-shaped, not space-shaped; S8 remains the real lever |
| **S7 fully verified** | Relay journal: "Root FS Early Warning (93%)" **triggered 20:37** (suppressed boot-grace) → **replay-forwarded 20:39 = real Discord page** → **resolved 22:22** as the frees crossed below 93%. Full detector lifecycle proven — red-and-paging, not phantom-green |
| **S24 verified live** | balance-watch-sim: /dev/kmsg injection detected (failures_total 0→1, recent_24h 1, ledger row, one real labeled Discord page by design). Caveat recorded: post-sim ledger truncate re-scans the journal and re-counts — drill flags decay naturally out of the 24h window |
| **S15 measured** | `unzip -l` of forgejo-20261027-033247.zip: **repos 26.86G = 96.5%**, data 73M, forgejo-db.sql 49M — growth driver is plain repo content; LFS/packages negligible. Retention-shape call (7d×27G) → owner via S13 |
| **S13 forgejo.md rewritten** | Storage section now enumerates ALL legs: daily pool zip (27G, measured), 8h btrbk subvol, ~~weekly dump (REMOVED, S3)~~, Sunday drill (CAP fix context) |
| **S18 verified** | SystemMaxUse=8G already set (boot.nix:619) and ENFORCED — journal sits at 8.1G ≈ cap. No action needed |
| **S16 ticked** | (DONE note was already in-row from a parallel pass; live re-probe matched: clip 5.7G + facial-recognition 631M + ocr 206M — ACCEPT verdict stands) |
| **dnsblockd relic trashed** | dnsblockd_tracking.db (724M) last-write 2026-07-15 = 104d untouched (≥30d rule) → trashed; tracking.db live. Bonus: journal.db is 4.3G of the 7.2G dir (S17 input) |
| **Hygiene** | eval-scratch{,2} worktrees removed; verify-train-a.sh anchor-comparison bug fixed (was comparing store path vs profile symlink — always-FAIL) |

## b) PARTIALLY DONE (in train B, sequencer-armed)

| Item | State |
| --- | --- |
| **S3 dump.disable** | Edited + eval-green; the 123G dump trash stays gated on a green drill |
| **Freshness sidecar bug FIXED** | gen-956 shipped `runtimeInputs = [ coreutils ]` — **awk/grep not in it** → `awk: command not found` at every run → `storage_collector_fresh 0` FOREVER + its gatus check permanently RED. Fixed (gnugrep+gawk added); post-deploy verify = gauge flips 1 |
| **btrbk resume_missing FAILSAFE — day-1 S23 was COUNTERPRODUCTIVE** | The 23:00 fire: fresh snaps took, but `!!! Target aborted: Failsafe mode active` — btrbk 0.32.7 DEPRECATED `resume_missing` and failsafes on it: ALL pool sends skipped (exit 10). Day-1's verify checked the line RENDERS, not that the binary accepts it. Line REMOVED (modern default always-resumes; the doc's imitation `target_preserve_min latest`+`target_preserve no` would prune the forever-pool — wrong for us). S23 burst-cap re-opened as a real fix |
| **Pool-copy perms FIXED** | 22:04 force-run failed: cp stat(DEST) EPERM — `/mnt/pool/services/monitor365` is owned by the AGENT user (monitor365) 0750, the unit runs as monitor365-server → no traverse. Fixed with the parent-chain tmpfiles rule (0711, forgejo run-98 lesson). Post-deploy force-run pending |
| **Drill timeout 30→60min** | The 20:41 force-run died at TimeoutStartSec=30min mid-verification (12.3G of 27G read under PSI 65 — IO starvation, NOT the CAP fix failing; it got past the permission stage that killed Oct 25). 60min budget + re-run staged (`run-drill-b.sh`) |

## c) SEQUENCED AFTER TRAIN B (tonight/tomorrow)

1. **btrbk full re-seed**: deleting the local snap chain means the next @ send to the pool is a FULL send (~600G logical, hours — deliberate, controlled, overnight; pool history through @.20261026T2329 is intact, no data gap, only send cost). Force-run post-deploy; guard-kill risk noted (catch-up-slot bar).
2. Post-B verifies: freshness=1, pool-copy lands on pool, drill re-run (60min), then S3's 123G trash if green.
3. 03:00 watch: monitor365 backup fits in 83G free (was the ENOSPC certainty at 14G); VACUUM may even succeed tonight (needs ≥43G headroom — HAVE 83G).
4. S6 balance: **pin gate GREEN NOW** (no pre-10-28 snaps), quiet gate RED (PSI). unalloc already 10GiB without balancing; run the ladder in a calm window for the ≥20G target (owner sudo per plan).

## d) TOTALLY FUCKED UP (radical honesty)

1. **I deleted snaps without foreseeing the full-re-seed cost** — the ladder was correct under the clock, but the "next send is FULL (~600G)" consequence of killing the local incremental chain landed as a discovery AFTER the fact. Should have been in the tradeoff up front. (Pool integrity never at risk.)
2. **`rg -rn` count: zero this session, but I typed bare `sudo`/`systemctl` in probes THREE times** (tail of the deploy log, ls of pool dirs, systemctl is-active) — guard-blocked each time, no harm, but the discipline is supposed to be automatic by now. Also glob-under-lss as lars twice (ladder-a's `sudo ls *.backup_*` expanded as lars → false "all backups gone" alarm for 60 seconds).
3. **The ladder-a cd bug** (`cd /var/lib/monitor365-server` as lars → EPERM exit) + a sed-with-pipes syntax error — two fumbled script edits before the clean run.
4. **rm error-spam**: the first cache rm printed ~185k Permission-denied lines before I noticed root-owned files inside (go module caches extracted by sudo go builds). Should have probed ownership first; the output file is in .crush/shell-output/ (noise, no harm).
5. **The balance-watch ledger "clear" re-counted** (failures_total 1→2) — the harness note's procedure was wrong about the journal re-scan. Left to decay; documented.

## e) WHAT WE SHOULD IMPROVE

1. **Rendered-config verifies must test BEHAVIOR, not presence** — both shipped-broken items (freshness awk, resume_missing failsafe) passed "does the line render" checks. The night caught them only because force-runs were in the plan. Candidate lint: for every writeShellApplication, shellcheck with runtimeInputs-only PATH; for btrbk config, `btrbk dryrun` exit code in pre-deploy checks.
2. **The pin-map probe should be standard before any reclaim estimate** — tonight's whole "S4 frees ~93G" expectation (plan-level!) was physically wrong (reflink sharing; S10 knew, the plan didn't ingest it).
3. **Trash-mtime ≠ pin logic** (see §a) — encode in storage.md's sweep doctrine.

## f) NEXT (ranked)

1. **Train B lands** (sequencer armed — waiting out parallel-session churn) → post-verifies (freshness=1, pool-copy, drill 60min, anchor discipline by NUMBER).
2. **btrbk full re-seed** post-B (overnight; verify receive lands + btrfs-verify-pool-backups greens next cycle).
3. S3's 123G dump trash on green drill; S13 already documents the leg map.
4. 03:00 observations: backup fits; VACUUM headroom now sufficient — stamp S9 evidence if the retention journal shows it ran.
5. S6 in a calm window (pin gate already GREEN; ladder `balance-s6.sh run`).
6. S8 next calm weekend (coordinate monitor365 sessions); S19 owner ruling STILL OPEN (buffer on pool, no root pressure from it).
7. Push coordination: ~25+ unpushed daemon batches (CI-safe; pin-audit artifact is dirty-tree-only) — held for owner ask per never-push rule.
8. µ27.3 ~/.cache watch row: re-base on the measured 49G (post-cleanup ~24G).

## g) QUESTIONS (cannot figure out myself)

1. **S19 ruling (unchanged, now the plan's only owner-gated blocker):** monitor365 agent back up vs retire? Gates the 32G buffer disposition + S27 close-out.
2. **Pool zip retention shape (S15/S13):** 7d×27G ≈ 189G of pool for repo content that also lives on the Samsung + 8h btrbk leg — right shape, or trim? (Owner call; data now measured.)

---

**Session artifacts:** all harness scripts + logs under `~/.cache/storage-crisis/` (sweep/verify/balance/trainb-sequencer/btrbk-2300-watch). Live mutations: ~11G cache rm (doctrine: rebuildable), 30 trash entries + 67G trash entry rm'd, 5 backup files pruned by the deployed policy (drain session's fire), 4 @ snaps + 2 .rescue snaps + eval-scratch worktrees deleted, dnsblockd relic trashed. **The 98% clock is broken; the box sleeps safely tonight.**
