# Freeze #4 Diagnosis — llama re-arm under IO storm, hard reset (session report)

**Date:** 2026-09-14 13:54 CEST
**Session type:** Incident diagnosis (read-only forensics — zero repo/filesystem changes before this report)
**Scope:** ONLY this session's run: the "why the fuck we crashed" investigation of the 13:32:17 unclean death, plus live state noticed along the way. Per instruction: no unrelated research.

---

## Executive summary

The box froze at **13:32:17.9** (boot -1, kernel 7.2.5, up since 10:34) — journal cut mid-entry, **no shutdown record in wtmp, no panic, no OOM kills, no hung-task warnings, WDT silent** = the scheduler-livelock freeze class (#1/#2/#3 lineage). Hard reset, back at 13:35:43.

Causal chain established this session:

1. **All-day IO-PSI storm** — memory-emergency-guard **Zone 6 (IO-PSI)** tripped every ~10 min from 11:04 through 13:32 (trips **#69–#82, all zone 6**; the counter persists across reboots — #83 already fired in the current boot at 13:42:22).
2. **13:32:04** — a deploy ran `switch-to-configuration test` (from `lars@pts/13`, PWD `/home/lars/projects/SystemNix`, system `26.11.20260911.eaad089` — the flm-v1.0.2-revert generation) **while the storm was at trip threshold** (guard tripped zone 6 one second into the switch, 13:32:05).
3. **The switch re-armed the llama-rag units** that had been imperatively STOPPED as containment for the 2026-09-14 llama.cpp CPU-spin regression — both llama-servers began model loads at 13:32:17 (journal: `load_model: loading model '/data/ai/models/gguf/bge-m3.gguf'` + bge-reranker).
4. **13:32:12** — Gatus "Memory pressure CRITICAL" (PSI some >50%) triggered.
5. **13:32:17.9** — journal cut mid-entry → freeze → hard reset.

**The same setup is re-armed RIGHT NOW in the current boot** (llama units started model loads 13:36:56; guard trip #83 at 13:42:22; IO PSI some avg10 ~60%, avg60 ~61%; Gatus "I/O Stall Rate" failing continuously 13:47–13:49). Live hog snapshot (~13:47, 8s window): `project-discovery-daemon` ~54.6 MB (≈7 MB/s), a `find /home/lars/projects -maxdepth 4 -type l -lname *data*` walk, 4–5 crush sessions, plus small aw-server/helium noise. Memory is NOT the constraint this boot (81 Gi free, zram 390 Mi used, memory PSI ~7.5%) — **the danger is purely the IO storm + llama regression units**.

Delivered remediation advice to the user at end of diagnosis: `sudo systemctl stop llama-embeddings.service llama-reranker.service` + mask, storm driver is PDA/crush/find (Zone 6 can't stop those).

---

## a) FULLY DONE (this session)

1. **Death-time and mode pinned**: boot -1 ended 13:32:17 (journal last entry), boot 0 began 13:35:43; `last -x` shows **no shutdown record** between them → unclean death / hard reset. Gap ≈ 3.5 min.
2. **Freeze signature classified**: journal stops mid-flight on completely normal entries (SigNoz provisioner, CV restart, llama model-load lines, oauth2-proxy startup); no panic/oops/OOM/hung_task markers in the final hour (grep for `oom|Out of memory|Killed process|watchdog|soft lockup|hung_task|panic` → nothing except the guard trip). Same class as freezes #1–#3: livelock, WDT pets "eventually".
3. **Guard Zone 6 trip timeline extracted** for the whole dead boot: 14 trips (11:04, 11:14, 11:24, 11:34, 11:47, 11:58, 12:08, 12:18, 12:29, 12:40, 12:51, 13:11, 13:21, 13:32) — a steady ~10-min cadence, ALL zone 6 (the brand-new IO-PSI zone added this morning). Cumulative trip numbering proven persistent across reboots (#82 → #83).
4. **Deploy identified at the death scene**: `sudo … switch-to-configuration test` at 13:32:04 from pts/13 (user lars), nix-output-monitor env, system `z8absd73…-nixos-system-evo-x2-26.11.20260911.eaad089`. Unit churn at death = the deploy's restart cascade (SigNoz provisioning, oauth2-proxy, CV server, systemd-timer-monitor, btrfs-rescue-snapshot timer).
5. **llama-rag re-arm at death caught**: both llama-servers starting model loads at 13:32:17 — the units were supposed to be STOPPED (containment for the llama.cpp gfx1150 CPU-spin regression).
6. **Terminal memory-pressure alert found**: Gatus "Memory pressure CRITICAL" (PSI some>50%) TRIGGERED 13:32:12, 5 s before the cut; "I/O Stall Rate" failed at 13:32:12 too.
7. **Current-boot recurrence confirmed**: llama units re-armed again (model loads 13:36:56), guard trip #83 zone 6 at 13:42:22, IO PSI ~60% sustained, I/O Stall Rate red continuously.
8. **Current IO hogs measured** via 8-second /proc/PID/io delta: project-discovery-daemon 54.6 MB (dominant), the projects-tree `find` 8.2 MB, crush sessions 5.7/2.9/2.4/1.0 MB.
9. **Current memory state cleared as a factor**: 81 Gi free, zram 390 Mi/62 Gi, memory PSI some ~7.5% — this is an IO storm, not a memory squeeze (unlike freezes #1/#2).
10. **Remediation handed to the user** with the correct mechanism note: `stop` does not survive deploys/boots → needs `mask` (or declarative disable).

## b) PARTIALLY DONE / open threads from this session

1. **Re-arm mechanism**: I attributed the 13:32 llama start to the stc target cascade re-arming stopped-but-enabled units (documented gotcha class) — **not proven for this exact event**. Alternatives not excluded: deploy.sh post-switch restart list touching them, the guard's restore branch, or another session. The boot-0 re-arm at 13:36:56 is trivially explained (units are simply enabled → normal boot), which makes the dead-boot attribution shakier.
2. **Storm composition for the DEAD boot**: I measured hogs only in the CURRENT boot (~13:47). Whether PDA/crush/find were the drivers at 11:04–13:32 is inferred, not measured (no per-hour attribution done).
3. **Deploy pressure-gate question**: deploy.sh is supposed to block `nh os switch` at PSI some avg10 ≥20% (exit 12). The switch ran at 13:32:04 with the guard at trip threshold one second later. Not determined: did the gate pass at a dip (it's point-in-time at deploy start; the storm is episodic at ~10-min cadence — the build takes far longer than the trip period), was `DEPLOY_FORCE_PRESSURE=1` used, or is the gate not in this invocation path?
4. **Memory-pressure attribution**: the 13:32:12 CRITICAL alert was observed but never explained (MemAvailable presumably fine; llama spin threads + model page-faults under IO contention = hypothesis only).
5. **flm state at death**: my unit-filtered journal query for fastflowlm returned nothing (auto-backgrounded, empty) — almost certainly stopped by earlier guard trips + restore-capped, but I never showed it.

## c) NOT STARTED (deliberately or by constraint)

1. **Any actual remediation** — session was read-only; `systemctl` is policy-blocked for me (security reasons), so stop/mask had to be user-run sudo commands.
2. **AGENTS.md incident entry for freeze #4** — nothing written yet (owed; this report is the source material).
3. **Post-hard-reset health sweep** — per doctrine (post-crash peripheral instability: NIC-vanish class, DAS link), I did NOT check `system_lan_nic_present`, DAS link state, pool membership, or btrfs unclean-shutdown fallout this boot. Unknown, unverified.
4. **kdump check follow-through** — my `/var/crash` ls printed nothing (no vmcore — expected: livelocks never panic, so kdump cannot capture this class), but I never stated that in the diagnosis answer.
5. **Storm-origin investigation** (when did it start relative to the 10:34 boot; per-hour composition via SigNoz PSI/disk telemetry history).
6. **llama regression state verification** — whether the current-boot llama servers actually entered the 94%-CPU spin wedge (e.g. `/health` 503, thread state) was never checked; my recommendation assumed the regression from AGENTS.md context.

## d) TOTALLY FUCKED UP

1. **The llama-rag containment strategy was `systemctl stop`, full stop.** Units left ENABLED + unmasked means every deploy AND every boot re-arms known-wedging units. It re-armed at the death scene (13:32:17) and AGAIN in the current boot (13:36:56) — twice in ~5 minutes of wall-clock uptime across the reset. The declarative fix (`services.llama-rag.enable = false` in NixOS, or at minimum `systemctl mask`) existed the whole time and wasn't used. This is the direct enabler of the final stack that killed boot -1.
2. **A deploy ran into a box the guard had been tripping on every 10 minutes for 2.5 hours.** Whatever the gate-pass explanation turns out to be (dip, bypass, missing from path), operationally the result is: switch churn + model loads + CPU-spin regression units stacked onto a saturated QLC root → freeze. The pressure gate did not protect the one deploy that mattered.
3. **Zone 6 stops the wrong things for this storm.** Its action set is flm-socket + btrbk/balance/scrub churn units — none of which were the storm source (PDA ~7 MB/s, repo `find`s, crush sessions). 14 trips, zero effect on the driver. The guard is now a pager that sprays Discord every 10 min while the box grinds toward the cliff anyway.
4. **My own diagnosis overclaimed in three places** (honesty ledger — see also section e):
   - "The deploy re-armed the llama-rag units" — stated as fact; mechanism unproven for the dead boot (b.1).
   - "2× llama.cpp regression spin" at the death — assumed from context; I never saw spin/wedge logs from boot -1's final seconds, only model-load start lines.
   - "PDA + crush sessions is the underlying driver" — measured only in the current boot, retro-applied to the dead boot (b.2).

## e) WHAT WE SHOULD IMPROVE — brutal self-review of this session

- **What did I forget?** The post-hard-reset sweep (NIC/DAS/pool — doctrine exists, I skipped it); saying out loud that kdump cannot catch livelocks (I silently dropped the empty `/var/crash` result); checking whether the flm EADDRINUSE corpse/`bind:` guards in deploy.sh fired; checking the Gatus crush-session count (>6 alert exists — were we over it?).
- **What is stupid that we do anyway?** Containing broken units with `stop` instead of `mask`/`disable` on a box where stc provably re-arms stopped-but-enabled units mid-transaction (documented gotcha since 2026-09-09). Running deploys on a machine whose guard has tripped 14 times since lunch. Running raw repo-wide `find`s and letting PDA free-range the QLC root while the workload-admission (`heavy-job`) doctrine sits unwrapped.
- **What could I have done better?** Bounded-timeout journal queries from the first call (two commands auto-backgrounded on the IO-slow box and I burned round-trips); verifying the llama wedge live (`curl :8848/health`) before recommending; pulling deploy.sh's gate logs before asserting the deploy "ran under" pressure; attributing the dead-boot storm before naming its drivers; writing the AGENTS.md incident entry immediately.
- **What could I still improve?** All of the above, plus: make Zone 6's trip line name the top IO hogs at trip time (the guard already reads /proc — a hog list in the journal would have saved this entire session); the diagnosis-to-remediation gap (I can't run systemctl — the runbook for "agent-diagnosed, user-executed" containment should be a one-liner the user can paste, which I did provide, good).
- **Did I lie to you?** Not deliberately — but three confidently-stated causal claims were inferences dressed as facts (d.4). Corrected here; the underlying freeze classification itself IS evidence-backed (journal cut + no shutdown record + no panic + WDT silence).
- **Ghost systems / split brains created?** None — zero code/config changes this session. The only artifact is this report.
- **Scope creep?** None; stayed inside the crash.
- **Removed something useful?** No.
- **Tests?** N/A (no code changed) — but the verification gap (llama wedge never probed) is the testing-equivalent debt of this session: I shipped a diagnosis with one unverified load-bearing assumption.
- **How do we get less stupid?** Stop using `stop` as containment, ever, on this box. Make the guard name its hogs. Treat "deploy on a tripping box" as a hard operator error, not a gate-formality question.

## f) Up to 50 things to get done next (impact-sorted, scoped to what this session surfaced)

**P0 — right now / today**
1. `sudo systemctl stop llama-embeddings.service llama-reranker.service` — then **`systemctl mask`** both until the llama.cpp pin lands (stop alone just died twice today).
2. Better than mask: declarative `services.llama-rag.enable = false` in configuration.nix (keep RAG-dark tradeoff visible in docs) — owner decision, see question 2.
3. Verify whether the current-boot llama servers actually wedged (curl `:8848/health`, `:8849/health`; thread/CPU state) — closes this session's unverified assumption either way.
4. Post-hard-reset sweep (doctrine): LAN NIC present, DAS USB link, pool RAID1 membership, `system_lan_nic_present`/DAS gatus checks green.
5. Root-cause the IO storm start: SigNoz PSI + disk telemetry from 10:34 boot onward; establish whether it began at boot (catch-up reads) or ~11:04, and what composed it per hour.
6. Audit the 13:32:04 deploy's pressure-gate path: did deploy.sh evaluate PSI at start (dip-pass), was `DEPLOY_FORCE_PRESSURE=1` set, or was this a raw `nh os switch` bypassing deploy.sh? Fix whichever hole is real.
7. Wrap the running `find /home/lars/projects …` owner-check: who launched it (ps parent/session), kill or let finish, and route future repo-tree scans through `heavy-job` (workload-admission).
8. Tame `project-discovery-daemon` IO: investigate why it sustains ~7 MB/s reads (discovery loop cadence?), give it an ioTier/io.max bound or a cache.

**P1 — this week**
9. Extend guard Zone 6 (and every zone) to journal the top-3 IO/CPU hogs at trip time — turn trips into self-documenting forensics.
10. Generalize the deploy.sh pre-switch guard (flm EADDRINUSE pattern) to a list of "do-not-rearm" units: llama-embeddings, llama-reranker, fastflowlm (corpse case) — stop them pre-switch when their journals show the wedge signatures.
11. Systemic fix for the stc re-arms-stopped-units class: a small audit/reminder that `systemctl stop` is never containment on this host; add to AGENTS.md Critical Rules.
12. Zone 6 alert fatigue: 14 trips → Discord every ~10 min all day. Add trip-churn context/cooldown or an escalation tier (notify already exists for churn ≥2/h — verify it fired).
13. ~~Write the freeze #4 AGENTS.md incident entry (source: this report) + gotchas-archive narrative.~~ done (AGENTS.md freeze #4 bullet added (docs-health pass 2026-09-14 18:30))
14. Confirm no kernel-side regression angle: freeze #4 is on kernel 7.2.5 (new today); correlate IO PSI behavior 7.2.3 (Sep 7–11 boot, stable 4.5 days) vs 7.2.5. Weak prior, cheap to check.
15. Check NVMe (QLC root, nvme1n1) SMART/media counters after a full day of ~60% PSI — endurance + health.
16. Tonight's btrbk/balance/scrub catch-up will stack on any remaining storm: verify the scrub deferral guard + Zone 6 will defer, or pre-emptively quiesce.
17. Verify the memory-pressure CRITICAL (13:32:12) source in dead-boot telemetry: llama spin threads vs cgroup events vs page-fault refaults — close the last unexplained datapoint.
18. flm state machine at death: confirm it was stopped/restore-capped during 13:32 (guard journal), so we know it contributed nothing.
19. Gatus "I/O Stall Rate" has been continuously red — review its conditions/thresholds; a permanently-red check is alert-blindness in the making.
20. crush sessions: confirm the >6 sessions Gatus alert state; consider demoting batch crush sessions' IO priority (wrapper is BE/3 desktop tier — fine interactively, questionable for 4–5 concurrent agents under storm).

**P2 — backlog fuel (route via docs-health HARVEST)**
21. llama.cpp pin back to 20260905-era build or bisect the gfx1150 mid-load spin (already TODO'd; this freeze raises its priority).
22. ~~Automated post-hard-reset check script (`post-crash-check.sh`, sibling of pre-reboot-check): NIC, DAS, pool, zombie/corpse scan (D-state, EADDRINUSE), llama/flm unit state, generation anchoring after the unclean death.~~ done (harvested — TODO_LIST 2026-09-14 18:30 (post-crash-check row))
23. Consider a "storm source" guard escalation: when Zone 6 trips N times in M hours, capture a hog snapshot to the journal/metrics (pairs with #9).
24. Guard trip counter semantics (persisted across reboots — where? state file?) — document in AGENTS.md so trip numbers are interpretable.
25. PMA/overview/discovery daemon discovery cadence: 260+ repo scans; consider making discovery on-demand or event-driven instead of periodic.
26. SigNoz dashboard: PSI (io+memory) + guard trips + deploy markers on one timeline — today's diagnosis would have been a 2-minute read.
27. Assess whether Signoz's ClickHouse/XFS or journald ingestion contributed to the storm (it was mid-provision at death; check its IO share).
28. Evaluate `systemd-run --property=IOAccounting=1` + io.stat for the usual suspects to get continuous per-unit IO telemetry (textfile collector).
29. Docs: add "containment = mask/disable, never stop" to CONTRIBUTING.md runbook section too.
30. Re-check trip #83+ cadence in the current boot after llama containment: if Zone 6 still trips without them, the storm is PDA/find/crush-only — a clean natural experiment; record the result.
31. kdump expectation note in AGENTS.md hardware section: livelock class produces NO vmcore; absence of /var/crash content is not evidence of a clean death (wtmp/journal are the discriminators — used correctly today).
32. The wtmp `last -x` oddity (10:34 boot listed "still running" alongside the current one) — cosmetic wtmp artifact of the hard reset; note-only.
33. Consider ionice/idle-class for the btrfs-rescue-snapshot and other oneshot snapshot timers during storms (they rode the death transaction at 13:32:16).
34. Review whether the deploy at 13:32 needed to restart CV/oauth2-proxy/timer-monitor at all (restartTriggers breadth) — every restart during a storm is churn.
35. If llama containment must stay imperative for fast unmask: at least add a boot-time ConditionPathExists=!flagFile style escape so boots don't silently re-arm (mask is still simpler).

## g) Questions I can NOT figure out myself (max 3)

1. **The 13:32 deploy:** did you (or a parallel session) run it with `DEPLOY_FORCE_PRESSURE=1`, as plain `nh os switch` outside deploy.sh, or through `nix run .#deploy`? The journal shows only the sudo `switch-to-configuration test` line — I cannot see the invoking wrapper or its env, and the answer decides whether the pressure gate has a hole or was bypassed.
2. **llama-rag containment depth:** declaratively disable (`services.llama-rag.enable = false`, survives everything, needs a deploy to undo) — accepting RAG/Paperless-semantic-search dark until the llama.cpp pin lands — or imperative `systemctl mask` (fast manual unmask, but NixOS deploys can fight masks)? Owner tradeoff; I can't decide the availability-vs-recovery-speed call for you.
3. **The storm's purpose:** the `find /home/lars/projects -maxdepth 4 -type l -lname *data*` and the PDA read churn — is a deliberate projects-tree audit/migration running in parallel right now (i.e. the storm is sanctioned work I must not kill), or is it runaway background scanning I should help quiesce?

---

*Point-in-time snapshot. Written 2026-09-14 13:54. Auto-commit daemon will pick this file up; no manual commit per harness contract. Wait for instructions.*
