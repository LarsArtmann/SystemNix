# Storage-Crisis Session 3 — FULL STATUS + SELF-REVIEW (owner-demanded)

**Date:** 2026-10-27 23:15 CET · **Session:** storage-crisis executor instance 3 (lineage: 15:53 → 18:51 → this)
**Plan:** `docs/planning/2026-10-27_11-49_SUPERB-storage-crisis-recovery-pareto-plan.md` (S1–S27)
**Companion:** `docs/status/2026-10-27_23-30_storage-crisis-execution-session3-crisis-broken-status.md` (the execution narrative written at 23:0x; this file adds the full self-review the owner demanded)

**One-line verdict:** **The 98%→100% clock is DEAD (root 99%→89%, 82G avail, unallocated 1MiB→10GiB, 94G reclaimed); train A is live and 6 of its 8 verify legs are green; train B (5 fixes, 2 of them catching MY OWN lineage's shipped-broken day-1 work) is armed on a sequencer still waiting out a parallel-session edit storm; everything left tonight is autonomously chained.**

---

## 0. Live state at 23:14

- Root `@`: **623G/723G, 82G avail, 89%**. btrfs cleaner finished. Device-unallocated 10GiB (metadata-ENOSPC precursor gone). The 03:00 monitor365 backup (~33-36G) now FITS with margin — at 21:16 (99%, 14G) it was a guaranteed ENOSPC corpse.
- IO PSI some avg10 ~93 (parallel-session storm: whisper×2 + builds + drain; peaked 97 at 23:09 — none of it mine; all my machinery is waiting, not loading).
- Train-B sequencer: armed, polls clean-but-never-4× (paperless session edits `modules/nixos/services/paperless-triage.nix` continuously; the tracked-files trap does NOT apply — the daemon already tracks it, evals stay green).
- Post-train-B orchestrator: armed (setsid, survived), will run anchor→freshness→pool-copy→btrbk full re-seed→drill(60min) autonomously once B lands.
- Tonight's btrbk 23:00 fire: local snaps took (`@.20261027T2300`); **pool sends refused — failsafe, see §d.1**.

## a) FULLY DONE (verified this session)

1. **Crisis relief ladder** (the §f.11-sanctioned stopgap, executed in order): ~/.cache rebuildable caches rm'd per doctrine (~11G instant — `/home` is NOT snapshotted by btrbk; the µ27.3 ">90G" figure was stale, live 49G→~24G) → precise dual-root empty of the 30-item S1 trash + the 67G forgejo.qlc-pre-subvol entry → early rotation of the 4 local @ snaps (10-25, 10-26×3) + the 2 incident-era `.rescue` snaps. **Result: 716G→622G used, 4G→82G avail, unalloc 1MiB→10GiB.**
2. **S7 root-fs alert — full lifecycle verified from the relay journal**: "Root FS Early Warning (93%)" triggered 20:37 (suppressed boot-grace) → replay-forwarded 20:39 (**real Discord page**) → resolved 22:22 as my frees crossed below 93%. Red-and-paging, not phantom-green.
3. **S4 pruner verified live**: the drain session's 22:02 backup force-fire exercised the deployed KEEP=2 — exactly 5 deletions (10-22, 10-23 fulls + all 3 corpses incl. the 16:14 off-schedule), 2 good rungs kept. Closed with the physical caveat (S10: backups reflink-share the live DB — 6.43GiB exclusive total — the prune was correctness-shaped, not space-shaped).
4. **S24 balance-watch verified live**: /dev/kmsg simulation detected (failures_total 0→1, recent_24h=1, ledger row, one real labeled Discord page by design).
5. **S15 measured**: newest pool zip = **repos 26.86G (96.5%)** + data 73M + forgejo-db.sql 49M — the 4G→27G growth driver is plain repo content; LFS/packages negligible.
6. **S13 forgejo.md Storage section rewritten** — all legs enumerated (daily pool zip w/ measurement, 8h btrbk subvol, dump leg REMOVED-S3 with rationale, Sunday drill w/ CAP history).
7. **S18 verified done-by-config**: SystemMaxUse=8G already set (boot.nix:619) and ENFORCED — journal sits at 8.1G ≈ cap.
8. **S16 immich cache**: live re-probe matched the in-row DONE note (clip 5.7G + facial-recognition 631M + ocr 206M — ACCEPT); box ticked.
9. **dnsblockd relic trashed**: dnsblockd_tracking.db 724M, last write 2026-07-15 (104d ≥ 30d rule); tracking.db live. Bonus: journal.db = 4.3G of the 7.2G dir (S17 input).
10. **Doc/queue hygiene**: 8 TODO/library rows stamped (S4, S15, S24, 67G-corrected, dnsblockd, S10-tick, S23-reopen, .rescue-watch); session report written + self-harvested (2 new rows: behavior-verify lint pair, pin-map doctrine); plan tombstone lineage updated; eval-scratch worktrees removed; verify-train-a.sh anchor-comparison bug fixed.

## b) PARTIALLY DONE

1. **Train B — all 5 changes eval-green, deploy sequencer-armed, NOT fired** (paperless edit-churn + PSI 90+ hold it): S3 `dump.enable=false` · freshness `runtimeInputs += gnugrep gawk` · drill `TimeoutStartSec 30→60min` · pool-copy parent-traverse tmpfiles rule · **resume_missing removal** (see §d.1).
2. **S2 drill**: the CAP fix IS deployed (got past the permission stage that killed Oct 25) but the force-run died at 30min TimeoutStartSec mid-verification (12.3G of 27G read under PSI 65 — IO starvation). 60min budget staged; re-run chained post-B.
3. **S5 pool-copy**: unit live, force-run failed on the traverse bug (root-caused + fixed in B); pool-side copy + freshness row verify pending B.
4. **S12**: the 14d tmpfiles rule is rendered live (verified alongside the upstream 30d — effective age = min = 14d), but µ12.2 (boot-evidence output → ~/.cache) and µ12.3 (shell-devtools note) were NOT done.
5. **btrbk pool leg**: local snapshots healthy (fresh `@.20261027T2300` + hermes twin); pool send blocked by the failsafe until B lands, then a deliberate FULL re-seed (~600G, hours — pool history intact through @.20261026T2329; the cost of tonight's rotation).
6. **S6 balance**: pin gate GREEN now (no pre-10-28 snaps), unalloc already 10GiB organically; quiet gate RED (PSI). `balance-s6.sh run` awaits a calm window — the ≥20G unalloc target is half-met without balancing.

## c) NOT STARTED (unchanged gates, this session made no attempt)

- **S3's 123G dump trash** (gated on a green drill — drill not green yet).
- **S1 `look` phase** — S22 hermes du + µ27.4 wevisone/@home: skipped, PSI-gated; a PARALLEL session is actively du'ing `/mnt/btrfs-root/@/home/hermes.old` right now (noticed at 22:26 — also: `hermes.old` itself is an @-resident reclaim candidate nobody has sized yet).
- **S8** monitor365 hot-tier migration (next calm weekend, coordinate drain session) · **S9** VACUUM watch (03:00 tonight has the headroom now — observation pending) · **S19** owner ruling · **S21** weekend scrub · **S20** E6 quality pair · **S27** close-out.
- **Push coordination** (~25+ unpushed daemon batches): held per the never-push-without-ask rule.

## d) TOTALLY FUCKED UP (radical honesty — the real list)

1. **I re-verified poison as PASS, myself, at 22:38**: `verify-train-a.sh btrbk` printed "PASS: resume_missing rendered" — I RAN that phase and accepted it while the option failsafes btrbk 0.32.7 into skipping ALL pool sends. The line was my own lineage's day-1 S23 work (predecessor instance), but tonight's verify was MINE and it tested the wrong property (rendering, not behavior). Caught only because the plan's 23:00-fire watch existed. The freshness awk bug (§b) is the same class — `runtimeInputs` checked by eyeball, never executed.
2. **I deleted the 4+2 snapshots without pricing the full-re-seed up front**: the ladder was the right call under a 3h clock, but "the next @ send is a ~600G FULL send because the local incremental parents are gone" should have been in the tradeoff BEFORE `subvolume delete`, not a discovery at 23:03. Backup integrity was never at risk (pool holds everything through 2329) — but the cost was real and unpriced.
3. **The false "ALL BACKUPS GONE" alarm (60 seconds)**: ladder-a's `sudo ls ...*.backup_*` globbed as LARS against a 0700 dir → empty → I briefly believed a parallel actor had wiped backups. It was the S26 glob rule, violated in a script I wrote an hour after re-reading the rule. The truth (the deployed pruner had done exactly its job) was one `sudo bash -c ls` away.
4. **Three guard hits on typed `sudo`/`systemctl`** (deploy-log tail, pool ls, systemctl is-active) — each blocked harmlessly, but the discipline is supposed to be automatic after 30+ sessions of documentation.
5. **The first cache rm spewed ~185k Permission-denied lines** before I noticed root-owned files inside go-mod/cv-go (sudo-go-build residue). Should have probed ownership before rm; the noise sits in `.crush/shell-output/`.
6. **Two fumbled script edits before one clean run** (ladder-a's `cd` into a 0700 dir; a sed with unescaped `|` in the replacement).
7. **The post-train-B orchestrator DIED on first arming** (nohup+& inside a tool-shell that exited — process-group kill; the btrbk-2300 watcher likely died the same way after logging only its header). Re-armed with setsid at 23:10 — 40 minutes of "armed" that was actually dead, caught only because I pgrep-verified at the end.
8. **The balance-watch ledger "clear" procedure re-counted the sim** (failures_total 1→2) — the harness note's own instructions were wrong about the journal re-scan; left to decay, documented.
9. **Carried-over from the lineage (my inheritance, my correction duty)**: the 18:51 "67G unpinned → immediate relief" premise was wrong (snaps CONTAIN the trash dir — nothing frees until rotation); both TODO surfaces + the 23-30 report correct it, but it shipped in a report I co-own.

## e) WHAT WE SHOULD IMPROVE (structural, from tonight's failures)

1. **Behavior-verify, not render-verify** — the two shipped-broken items both passed presence checks. Concrete: (a) writeShellApplication scripts get a shellcheck/execution leg with runtimeInputs-ONLY PATH; (b) pre-deploy-check runs `btrbk dryrun` and gates on exit 0. (Harvested: pipeline.md row.)
2. **Pin-map probe before ANY reclaim estimate** — trash-mtime is never pin evidence; fi-du physical math is mandatory (the S4 "~93G" plan-level expectation was physically ~0; tonight's 67G claim was wrong the other way). (Harvested: storage.md row.)
3. **Price irreversible ops' second-order costs up front** — snap deletion → send-parent loss → full re-seed. The ladder doc should have carried the line "and the next pool send goes full (~600G, hours)".
4. **Armed-is-not-running**: any backgrounded helper must be pgrep-verified AT ARMING TIME (and ideally setsid from the start). Two silent deaths tonight.
5. **The 03:25 pool-copy timer will fire on gen-956 if B lands late** → one failed unit + silent OnFailure overnight (self-heals on the next post-B fire). Tolerable, but it argues for a "deploy before timer X" awareness in sequencer design.

## f) NEXT (ranked, from tonight's state — not a re-audit)

1. **Let train B land** (sequencer armed) — then the orchestrator runs: anchor-by-number → freshness=1 → pool-copy force-run + pool-side ls → **btrbk full re-seed** (overnight, hours) → drill re-run (60min budget).
2. **Morning verify pass**: btrbk receive landed + `btrfs-verify-pool-backups` re-greens; drill journal both legs; `storage_collector_fresh 1`; 03:00 backup journal (fits in 82G); 03:25 pool-copy post-B state.
3. **S3's 123G dump trash** on green drill (owner `sudo trash /var/lib/forgejo/dump/*` per plan µ3.3 — or I run it via harness after the drill greens).
4. **S6 balance** in a calm window: `balance-s6.sh check → run` (pin gate already GREEN; reserve rm + re-provision per ladder µ6.3/µ6.6; target unalloc ≥20G — 10G already there).
5. **S9 evidence**: 03:00 retention journal — VACUUM has ≥43G headroom for the first time in weeks; stamp if it ran.
6. **hermes.old sizing** (parallel session is mid-du; coordinate) — @-resident old home, unknown G, now unpinned-ish candidate.
7. **S1 `look` phase** (S22 + µ27.4 wevisone/@home) at PSI<25.
8. **S8** monitor365 hot-tier migration next calm weekend (the REAL structural fix — the DB churn stays on QLC until then).
9. **S19 ruling** (owner) → buffer disposition → S27 close-out.
10. **S21** weekend scrub (root+/data) — post-S6.
11. **S20** E6 ship-quality pair (fixture + cross-guard) — anytime.
12. **µ12.2/µ12.3**: boot-evidence output → ~/.cache + shell-devtools note.
13. **S23 burst-cap, the REAL fix** (modern btrbk: calendar hardening or stray-target GC — not resume_missing) — row re-opened with the failsafe post-mortem.
14. **Behavior-verify lint pair** (§e.1, harvested).
15. **Pin-map doctrine** into docs/agents/storage.md (§e.2, harvested).
16. **zram watch**: 77% observed at 22:33 under storm (bar is 80) — one more pressure leg from the drain workload; if it crosses, the balance quiet-gate stays shut.
17. **Emergency reserve state changed**: with the snaps gone it is UNPINNED again — an instant 10G relief valve; keep (balance ladder manages it) but record the changed pin state in the runbook.
18. **Freshness gatus check is RED until B lands** (the broken gauge) — expect one more Discord cycle tonight; resolves on B.
19. **Push coordination** on owner ask (~25+ batches, CI-safe).
20. **µ27.3 ~/.cache row re-base**: 49G measured, ~24G post-cleanup (the >90G threshold figure is stale).
21. **The 5 unchecked train-A legs from the deploy's exit-3** (runner inactive = runner-health session; monitor365 agent = S19; InboxClean = confirmed stale-settle) — nothing mine, but they ride the morning verify.
22. **journal.db 4.3G growth** (S17 input from tonight's dnsblockd probe) — dnsblockd.md owns the retention question.

## g) QUESTIONS (cannot figure out myself)

1. **S19 — the last plan-blocker you own:** monitor365 agent back up vs retire (plan row 558)? Gates the 32G frozen buffer disposition and, with it, S27 close-out. (The buffer sits on the pool subvol — no root pressure — but the ruling also shapes S8's retention redesign.)
2. **Overnight deploy autonomy:** the train-B sequencer will fire `nix run .#deploy` (DEPLOY_FORCE_PRESSURE=1) whenever 4 clean minutes + PSI ≤80 (2-min) align — possibly 2am under the storm. Alternative: I hold it for a morning window you pick. Leave it armed, or time-box it? (If B lands AFTER 03:25, the pool-copy timer fires once against gen-956 and fails silently — self-heals post-B; noted so the noise isn't a surprise.)
3. **The btrbk full re-seed timing:** fire immediately post-B overnight (~600G read QLC + write pool, hours, guard-kill risk under storm — retries next window automatically), or schedule it into a calm window (weekend) since the pool leg is only one day stale? My default (armed): overnight immediately — backup-freshness beats storm-tidiness.

---

**Machinery state at handoff:** trainb-sequencer (pid 2103180, alive, polling) → deploy → posttrainb orchestrator (pid 3810769, setsid, watching for B's exit). Logs: `~/.cache/storage-crisis/{trainb-sequencer,posttrainb}.log`. Report of record for the execution arc: `2026-10-27_23-30_storage-crisis-execution-session3-crisis-broken-status.md`. **The box sleeps safe: 89%, 82G free, 03:00 fits, backup history intact on the pool.**

**Waiting for instructions.**
