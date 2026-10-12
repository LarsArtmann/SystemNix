# Session Report: Freeze #28 Crash Diagnosis ("Why did we crash?") — Live Recovery Storm, Numbering Correction, Self-Review

**2026-10-12 13:15 CEST · scope: ONLY this session's run** (user asked "Why did we crash?" at ~13:06; diagnosis 13:06–13:07, verification + this report 13:08–13:15). Parallel sessions may be active on this tree; every green here is point-in-time.

---

## ⚠️ STILL TRUE AT AUTHORING TIME — READ FIRST

**The box is STILL in the post-crash recovery IO storm.** At 13:11:56 (6 min into the current boot):

- IO PSI: **some avg10=81.9% / full avg10=76.5%**, load 30.9 (memory PSI ≈ 0, MemAvailable 79.5% — pure crash-#3 class)
- Guard **tripped zone 6 again THIS boot** (trip before 13:10, cooldown heartbeat at 13:10:41: "I/O PSI some avg60=78.08% sustained, max disk busy 100.0%, MemAvailable=79.5%")
- Still in D-state: `discordsync-db-heal` sqlite3 (pid 1580, since 13:05), clickhouse `find` walk, both `llama-server` cold-loads (bge-m3 + qwen3.6-35b ~20 GB from QLC), postgres, **btrfs-cleaner**
- The containment I recommended at 13:07 (`sudo systemctl stop crush-hot-db-migrate discordsync-db-heal` — the freeze-6 rule (a)) was **NOT executed** (needs owner sudo; agent guard blocks systemctl). This is the **7th documented post-crash re-fire** of the recovery-reader class. **Freeze #29 wants to happen while this storm runs.**

---

## a) FULLY DONE

1. **Crash diagnosis with full evidence chain (freeze #28: boot Oct 11 11:09 → hard journal cut Oct 12 13:04:01, hard reset 13:05).**
   - Journal cut mid-activity at 13:04:01, **no panic, no vmcore, no shutdown record** — the livelock discriminator (documented class: freezes #1–#7/#12 lineage).
   - **46 OOM-killer invocations across the boot** (00:35, 01:57, 02:04, 02:15, 08:18, 12:32 …): nightly memory churn from `nix` builds (~4 GB RSS each, several, protected adj −1000), crush sessions, `bun` (18 GB VSZ), chromium, python3.13.
   - **08:18:56**: global OOM killed `systembus-notif` **and `niri`** (the compositor died ~5 h before the crash — desktop session loss that went unremarked in-session).
   - **12:18–13:00 guard war**: memory-emergency-guard tripped **5× (#2799–#2803)** — zone 6 (IO PSI some avg60 up to **89%**, disk 100% busy) and zone 1 (**MemAvailable 4.0% → 3.1%** absolute floor). Every trip EXECUTED its action (sockets + flm stopped). Ineffective: the guard's own IO attribution shows **system.slice +60–93 GB and user.slice +28–64 GB per ~10-min window** — the drivers were never in the sacrifice list (freeze-25 §d4 class: "guard action executed, ineffective").
   - **12:32:14 global OOM cascade**: kswapd0 invoked oom-killer repeatedly within one second — killed `bun` (adj 1000), `.ollama-wrapped` (adj 500), `llama-server` **41.7 GB total-vm** in `llama-chat.service` (adj 300). Node state: free 4.4–4.6 GB vs 2 GB min watermark, anon ~43 GB, **zspages 33.8 GB** (zram physical). The protected nix builds kept the box pinned at the floor.
   - **12:32 → 13:04 terminal crawl**: kernel log silent after 12:32, userspace limping (gkr-pam keyring failures, `systemd-inhibit` denials every 30 s — actor unidentified), last guard tick 13:03:31 (finished "successfully"), journal cut 13:04:01.
2. **Live recovery-storm census at 13:07 and re-verified 13:11** — D-state actor → cgroup mapping: `discordsync-db-heal.service` (sqlite3 `PRAGMA integrity_check` on the discordsync DB), `hermes.service` (sqlite3 integrity_check on /home/hermes/state.db — **new member** of the recovery-reader class), `mandb.service` (full-tree `rsync --checksum`), `clickhouse.service` (`find ! -user` walk), `crush-hot-db-migrate.service` (find over /home/lars/projects), plus both llama-servers cold-loading into the storm. Containment command delivered with rationale.
3. **Guard + sev1 behavior verified for the crashed boot**: 5 trips executed (above), and **sev1-bridge fired notify-tier at 13:03:49** ("MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED") — **15 seconds before the journal cut**. The storm ran ~45 min (12:18 → cut); the human-loop layer became visible in its final 15 s.
4. **Freeze numbering verified and corrected** (see §d — the correction is the honest part): **#26 = 2026-10-07 revoked-sweep incident** (docs/status/2026-10-07_11-26_freeze-26-autopsy-sweeps-revoked-license-pty-breakage.md). **Oct 10 23:15 boot died in a hard journal cut at Oct 11 11:07:59 = freeze #27, UNDOCUMENTED** (no autopsy, no library row, verified absent in docs/todo/stability.md + TODO_LIST.md). **Oct 11 11:09 → Oct 12 13:04 = freeze #28 (this diagnosis).** Five boots in 6 days (Oct 7 ×2, Oct 10, Oct 11, Oct 12), all "still running" in wtmp = all hard-cut endings.
5. **Queue/library premise checks done at authoring time** (per the queue-premise rule):
   - Guard `ioChurnUnits` contains **neither `discordsync-db-heal` nor `crush-hot-db-migrate`** — freeze-6 rule (b) ("extend ioChurnUnits with those two units") **never landed**.
   - The resumable-reader pause-automation row EXISTS (docs/todo/stability.md:174) — today is its **7th re-fire proof**, amended (not duplicated).
   - No freeze-27/#28 rows existed anywhere → new rows are legitimate.

## b) PARTIALLY DONE

1. **Crash attribution reached CLASS level, not ACTOR level.** The writer behind system.slice's 60–93 GB/10-min IO windows is unnamed (candidates: clickhouse/SigNoz ingest, postgres, llama-rag (uid 975 server survived in the 12:32 dump), tq pool lineage, immich ML). Same for the protected nix builds (4 GB × N, adj −1000): which workflow spawned them overnight is unknown (suspects: daily CI-class jobs — nixpkgs-compat/go-deps-audit — or agent session builds).
2. **Freeze #27**: existence established (hard cut Oct 11 11:07:59 after a ~12 h boot, no shutdown record) — zero autopsy, zero cause. It sits undocumented between #26 (Oct 7) and #28 (Oct 12).
3. **Containment: recommended, not executed, not verified.** Still storming at 13:11 (see banner).
4. **zram state stated imprecisely**: 33.8 GB is zspages PHYSICAL; the logical swap fill (mm_stat) was never computed — "near capacity" was an inference, not a measurement.

## c) NOT STARTED

- stability.md freeze-#28 entry (hardware-instability list) — the diagnosis lives only in this report + chat so far
- Freeze #27 autopsy (journal -3…-2 forensics; journal may still be present — unverified)
- Per-unit IO attribution for boot -1 (the 5s writer-attribution pass, per the 2026-10-06 rule, was done for the CURRENT boot only)
- Journal evidence preservation (OOM dumps, guard logs) before vacuum — the Oct-3 cascade triage later found "journal vacuumed"; same risk here
- Post-hard-crash hardware checks: LAN-NIC present (warm reboot does not retrain RTL8125 — 2026-08-22 lesson), DAS/pool mount state, boot-mirror sync state this boot
- The 30-second `systemd-inhibit` retry actor identification (12:32–13:04)
- niri OOM-kill (08:18) user impact assessment

## d) TOTALLY FUCKED UP (honest accounting)

1. **I mislabeled the crash "freeze #26" in the session's first reply — the correct number is #28.** Root cause chain: my verification grep (`rg 'freeze[- ]#?\d+'` piped to `sort -t'#' -k2 -n`) field-sorted on '#', silently mishandling the hyphenated `freeze-26` form; the scan also covered only docs/agents/stability.md + docs/status/*.md top level, missing docs/todo/stability.md where #26's revocation record lives. A wrong fact was delivered as a diagnosis headline. Corrected 13:12–13:14 only because the user's ritual forced a second pass.
2. **I missed freeze #27 entirely on the first pass.** wtmp showed five boots; I checked only boot -1's ending. The Oct 10 23:15 boot's hard cut surfaced only during numbering verification. Crash triage that reads one boot tail under-reports crash frequency — exactly the "assert WHICH question your evidence answers" class.
3. **I recommended an action I cannot execute, with no verification loop attached.** The stop command needed owner sudo; I neither flagged "reply after running and I'll verify PSI drains" nor offered any fallback. Result: containment unverified 8 minutes later, storm ongoing.
4. Minor: stated zram "near capacity" from physical zspages without computing logical fill (see b4).

## e) WHAT WE SHOULD IMPROVE (session lessons)

1. **Freeze-number verification = full-corpus numeric extraction** (`rg -o … | grep -o '[0-9]*' | sort -n | tail`), never a field-split sort on a separator some forms omit. Applied in the correction pass; should be the standing method for any "next N" naming.
2. **Crash triage must check the ending of EVERY recent boot** (wtmp → `journalctl -b -N | tail`), not just boot -1 — crash clusters hide in boot -2 and further back.
3. **Owner-action recommendations always carry the verify step + offer**: "run X, then I re-probe PSI" — an unverified recommendation during a live storm is a coin flip left in the air.
4. **OOM-dump zspages ≠ swap fill** — compute logical (mm_stat) or label the figure "physical, compressed" explicitly.
5. **sev1 notify-tier timing for IO-class storms is functionally invisible**: 45-minute storm, first human-visible notify 15 s before death. This is more proof for the existing [blocked:user] Zone-6 action-split row — the human loop cannot be the containment for a class that kills in <60 s from notify.
6. **The recovery-reader class now has SEVEN proofs and still no automation** — every crash since freeze #6 has re-paid the same boot tax. The pause-automation row (stability.md:174) has been [ready] through at least four of them.

## f) Things we should get done next (ordered by impact; 1–2 are live-fire)

1. **[URGENT, owner] Contain the CURRENT recovery storm**: `sudo systemctl stop crush-hot-db-migrate discordsync-db-heal` (both next-run-converge) — freeze-#29 prevention, still pending at 13:15.
2. **[URGENT, agent] Preserve freeze-28 evidence before journal vacuum**: dump boot -1 kernel OOM dumps + guard journal + boot -2/-3 tails to docs/status evidence files (the Oct-3 triage lost its journal to vacuum).
3. Freeze-#28 entry in docs/agents/stability.md hardware-instability list (this report is the source).
4. Freeze-#27 autopsy: boot Oct 10 23:15 → Oct 11 11:07:59 hard cut — cause completely unknown; check guard trips/IO attribution/thermal in that boot's journal.
5. Per-unit IO attribution for freeze-28's system.slice writer (60–93 GB/10 min): clickhouse vs postgres vs llama-rag vs tq vs immich — name the actor, kill the class.
6. Identify the overnight protected nix builds (4 GB × N, adj −1000) in boot -1: which workflow (nixpkgs-compat daily? go-deps-audit? agent builds?) — nightly build memory policy depends on it.
7. Land the resumable-reader pause automation (stability.md:174 — 7th proof today; hermes integrity_check is a NEW member; btrfs-cleaner D-state this boot may belong in the class too).
8. Extend guard ioChurnUnits with discordsync-db-heal + crush-hot-db-migrate (freeze-6 rule (b), verified absent today — six weeks stale).
9. Zone-6 action-split ([blocked:user] row): today adds the third "action executed, ineffective" structural proof — owner decision requested (see §g).
10. hermes.service sqlite integrity_check at every boot — move to weekly/condition (new recovery-reader finding).
11. mandb full-tree `rsync --checksum` at boot — gate behind PSI/heavy-job serialization.
12. clickhouse `find ! -user` walk at every start — audit necessity + frequency.
13. system_health.prom census emitter missing-newline bug — live parse error at line 675 (`70447521792system_cgroup_mem_anon_bytes{...}` value+label concatenated) causes WHOLE-FILE textfile rejection (the Gatus canary row's failure mode, observed live this boot).
14. storage-collector.prom unreadable by node_exporter ("permission denied", live this boot) — ownership/permission fix + fail-closed visibility.
15. llama-chat MemoryMax vs 41.7 GB total-vm coherence (memory-watermark-audit scope; adj-300 sacrifice died with 68 MB pgtables — check the cap is doing anything).
16. Post-cold-load PSI admission gate for model services (llama-chat/llama-rag/ollama): no cold load while io-PSI avg10 >40 — both llama-servers loaded into a 76% storm this boot.
17. Compute zram logical fill from the freeze-28 OOM dump (mm_stat equivalence) → decide whether the 50% (62 GiB) sizing needs a revisit or the cliff was purely anon+shmem volume.
18. Nightly OOM churn policy: 46 kills in one boot is a standing regime, not an incident — heavy-job serialization for overnight builds + agent sessions (feeds the no-build admission lineage freeze-14/15/18/20).
19. Identify the 30-s `systemd-inhibit` retry actor during the 12:32–13:04 crawl (DMS? niri? session manager?) — understanding what userspace does while the kernel dies.
20. sev1 notify timing for sustained IO storms (see e5) — at minimum a storm-duration-clock notify ("IO storm >20 min") rather than condition-edge notifies.
21. Post-hard-crash hardware checklist executed THIS boot: LAN-NIC present, DAS/pool mounted, boot-mirror sync OK (all unverified; freeze #28 was a hard reset — the 2026-08-22 NIC class says verify).
22. Guard drift-check scope: it verifies ioChurnUnits entries EXIST on the system — not that the storm's readers are IN the list (coverage blindness, today's proof; links #7/#8).
23. niri killed by global OOM at 08:18 (adj 100) while adj −1000 builds survived — desktop-first victim ordering under build storms; consider user-session protection or build memory caps (systemd-run scope MemoryMax for nix).
24. Crash-frequency trend row: five hard-cut boots in 6 days (Oct 7 ×2, 10, 11, 12) — the freeze family is accelerating; worth a dedicated look at what changed week-over-week (kernel 7.2.9 pinned Oct 3 + workload).
25. node_exporter connection-reset spam under storm (scrape timeouts) — cosmetic, but bump scrape_timeout if storms are the new normal.
26. gkr-pam keyring unlock failure storm during the crawl — cosmetic vs session-loss signal; one grep when the box is calm.
27. Freeze-28 forensics bundle: link this report from stability.md when the entry lands (§3) and cross-link freeze-27 when its autopsy exists (§4).
28. btrfs-cleaner D-state 6 min into recovery boot — post-crash cleanup IO; evaluate pause-class membership (with #7).
29. This boot's multi-user.target reach time — freeze-6 measured 15 min; today's number unknown; make it a standard post-crash metric (one journalctl command).
30. Census ingest-gap durability ring (existing row, TODO_LIST.md:145) — freeze-28 is another proof: the top-8 cgroup census data that would answer "who held 43 GB anon" died with the textfile rejection (#13).

## g) Questions I can NOT figure out myself

1. **Containment now**: the box was STILL storming at 13:11 (PSI full avg10 76%, discordsync-db-heal running since 13:05). Do you want to run the stop command yourself (`sudo systemctl stop crush-hot-db-migrate discordsync-db-heal`), or should containment wait / go a different route? I cannot execute sudo systemctl, and the storm is live while we talk.
2. **Freeze #27 context**: the Oct 10 23:15 boot died in a hard cut at Oct 11 ~11:07 (Sunday morning). Do you remember what was running / what the desktop showed when it died? The journal tail gives nothing after the cut, and no session documented it — your memory may be the only missing evidence.
3. **Zone-6 action-split ruling**: today freeze #28 executed 5 trips (sockets + flm stopped each time) and they changed nothing — the third structural proof after #24/#25 that memory-shaped sacrifice is the wrong tool for IO-class trips. The fix row sits [blocked:user] awaiting your go. Should today's evidence unblock it (or change its shape)?

---

## Harvest record (per the TODO-system authoring rule)

- TODO_LIST.md ← 4 new [ready] rows: freeze-27 autopsy, freeze-28 stability entry, system_health.prom newline bug (→ monitoring), storage-collector.prom permissions (→ monitoring)
- docs/todo/stability.md ← freeze-27 + freeze-28 rows added; :174 pause-automation row amended with the 7th re-fire proof
- docs/todo/monitoring.md ← 1 new row (both textfile-collector defects, live-evidenced)
- Deliberately NOT harvested: containment (§f.1, owner-action), Zone-6 unblock (§g.3, owner decision — existing [blocked:user] row already carries it), niri-loss impact (§g-adjacent, user memory)

*Report format: Markdown at explicit user path demand (standing .md exception; HTML-canonical skipped — flagged per skill contract). No commit made: harness forbids unprompted commits; the auto-commit daemon will sweep this file.*
