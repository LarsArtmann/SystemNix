# Status Report — PSI Band 80 + Guard Catch-Up Enrollment + Storm/Reboot Forensics

**Session:** 2026-11-14 ~14:35–16:55 CET (continuation of the 14-03 shadow-split session; owner answered its Q1/Q2 mid-afternoon).
**Live state at authoring:** freeze #54 cut the box 15:41:18→15:41:46 (WDT, 28 s gap); recovery boot is in an extreme storm — IO PSI avg10/60/300 ≈ 99, load 1050+, ~96 `ld.mold` linkers D-stated on `balance_dirty_pages` in SSH session-26 (started 15:46:58), buildcache sdb write-saturated. **The deploy gate correctly refuses everything; nothing deployable until the battery ends or is contained by the owner.**

## a) FULLY DONE

1. **Owner Q1 answered — `~/tmp` frozen shadow inventory (25G)**: pure reproducible scratch — go-cache 13G, go-mod 4.7G, ~8 go-build* scratch dirs ~4G, go-lint 1.4G, tmpdir 812M, ~180 identical 4.2M `brandidlint.*` binaries (~0.75G), thousands of tiny `tmp.*`/`devshell-tools.*` droppings (all Oct 27–Nov 2, pre-cutover; live Samsung subvol ~378KB). **Recommendation: dead weight — nothing to pull forward** (survives in old `@` pool receives regardless). Recorded: storage.md row-14 UPDATE + the 14-03 report addendum.
2. **Owner Q2 executed tree-side — btrbk admission IO band 20→80** (commit `5013fd42c`): `btrbkAdmission` wrapper now passes `--psi-max 80`; shared `maintenance-entry-gate` default stays 20 (gc-guard/migrate/psi-wait/deploy gates untouched); 60-min guard-trip window untouched. Pre-commit battery green incl. all-systems eval.
3. **The watch row's "calm-window catch-up mechanism" landed structurally** (commit `693d359a3`): btrbk-projects enrolled in the guard's `ioChurnUnits` (mid-send storms get the send stopped like the other four legs) AND `backupUnits` (starvation slot: avg60 <50 → 900s-protected start — paired with the avg10<80 gate this catches up automatically, no agent in the loop). VM-test drift assertions are membership-style (verified safe).
4. **Docs coherent**: stability.md watch row (2 UPDATEs), storage.md rows 14 + 192 (precondition now cites band 80), CHANGELOG entry, 14-03 report addendum, cvagent P0 row in services.md (commits `b7f1eb241`, `8c5e893ab`, + daemon-swept `033c557c8`).
5. **cvagent stopped as storm engine** (16:10): attribution showed it the dominant system.slice reader (32–52 MB/s sustained; 18.4 GB lifetime for the 15:41 instance) while serving 503 `/health` + 500 `/` (`app.facts` infrastructure errors) — a read-only dashboard serving nothing healthy. Reversible: `sudo systemctl start cvagent.service` (expect the read storm to resume until its fix lands — P0 row queued).

## b) PARTIALLY DONE

1. **The deploy of the band+enrollment changes — committed, NOT deployed.** The afternoon storm never opened the gate (io avg10 floor 35–99 all session). A calm-window auto-fire waiter (`~/.cache/band-deploy2.log`, conditions: io<20 ∧ mem<20 ∧ trip-free ≥15 min, 2 consecutive samples) is armed and correctly holding. The parallel gen-1007 deploy (13:54–14:56) predates both commits and does NOT carry them.
2. **The catch-up green run** — blocked behind the deploy (admission on the LIVE system is still band 20; a manual `systemctl start btrbk-projects` now would be refused at 99% IO + trips anyway).
3. **Post-deploy verification battery** — prepared, not runnable: `systemctl cat btrbk-projects` ExecCondition → store path greps `--psi-max 80`; fire unit; verify new `projects.<ts>` receive in `/mnt/pool/backups/projects-subvol`; `projects_subvol_backup_fresh` flips 1 within the 5-min metrics timer.

## c) NOT STARTED

- The §18 polish bundle and the automount live-proof (harvested [ready] rows) — deliberately deferred: editing deploy-relevant scripts while a deploy waiter is armed is the mid-edit race class.
- The shadow-cleanup itself (owner-gated: Q1 sweep confirmation + Q3 tar.zst ruling pending).

## d) TOTALLY FUCKED UP (self-review, brutal)

1. **I sat through freeze #54 without noticing for ~70 minutes.** The box died 15:41:18 and rebooted 15:41:46; I rationalized away THREE independent signatures: (a) `/proc/pressure` totals dropping ~45× (15:47 — I called it "a known anomaly"), (b) cvagent "restarting" at 15:41:53 with low PIDs (1882, 2697) after a morning of high PIDs (99433, 1379434), (c) the 15:39 mem avg10=95.8 spike that avg300 washed out. A 10-second `cat /proc/loadavg` or `journalctl --list-boots` at any of those points would have named it. Consequence: my 16:07 forensics of "cvagent crash-loop restarts" mixed pre-crash events (13:21/13:43 oom-kills, 14:04/15:27 exit-2) with the BOOT re-arm (15:41) — the queued P0 row slightly misreads 15:41 as a loop restart (correction note in §f; the oom-kill loop itself is real).
2. **First cgroup scan was write-only and head-limited** — took two extra scans (~20 min) to find cvagent because reads (rbytes) weren't in the first pass. The sanctioned pattern should always be rbytes+wbytes, full cgroup set.
3. **`rg -rn` third strike on this host** (hook blocked it — correctly). The documented trap still caught me.
4. **Two index.lock races** (parallel sessions): the first delayed my docs commit ~15 min; the second lost the P0-row commit entirely (daemon swept it — content landed, attribution rode a heuristic).
5. **My own pre-commit flake checks (×3 evals) fed the very storm blocking the deploy** — marginal bytes, but the box was at the edge; the capture-once discipline existed and I still triggered full eval batteries per commit.
6. **The cvagent stop was 25 minutes late** — I spent that window reading its journal/history when the attribution had already named it and its /health was 503 the whole time.

## e) WHAT WE SHOULD IMPROVE

1. **Reboot-signature checklist** (session-resume class): `/proc/pressure` TOTAL counters reset + suddenly-low PIDs + load-average discontinuity = boot happened; run `journalctl --list-boots | tail -2` before ANY multi-minute forensics on a "stormy" box. This belongs next to the existing boot-evidence rules in AGENTS.md session discipline.
2. **Cgroup attribution one-liner** should be the FIRST probe for any PSI storm (rbytes+wbytes, all of system.slice+user.slice, 30 s) — before journal reads, before process-name pgrep filters.
3. **Waiter horizon discipline**: arm the calm-window waiter through the NEXT meaningful deadline (23:10 tonight), not an arbitrary 90/150 min — a dead waiter silently abandons the deploy.
4. The freeze-#54 morning report (parallel session's freeze-52/53 doc) + this session's evidence both point at **SSH-session build batteries as un-gateable storm engines** — the stability-crisis Pareto plan (24e35a515) owns the structural fix; my data point: session-26 started 4 minutes POST-BOOT into the recovery storm (the crash-recovery amplifier class, freeze #6/#25 lineage).

## f) NEXT

1. **Owner, urgent**: the session-26 SSH build battery (96 linkers, load 1050, sdb saturated — freeze-#49 signature on the freeze-#54 recovery boot) — stop it or let it finish; it blocks every deploy and risks freeze #55. (Question 1.)
2. When the storm drains: the armed waiter auto-fires the deploy (band 80 + enrollment); then verify ExecCondition carries `--psi-max 80`, fire `sudo systemctl start btrbk-projects` at io<80 ∧ trip-free, verify the new pool receive + `projects_subvol_backup_fresh 1` (precondition 1 of the 132G shadow-cleanup).
3. Correct the cvagent P0 row's 15:41 line (boot re-arm, not loop restart #3).
4. cvagent fix session (P0 row): app.facts 500s root-cause; why 1G MemoryMax still oomd-kills; the read-retry loop coupling.
5. Owner decision: restart cvagent now (storm resumes) vs leave stopped until fixed. (Question 2.)
6. Owner decisions on the shadow bundle: confirm tmp sweep (dead weight) + tar.zst keep-vs-skip. (Question 3.)
7. §18 polish bundle + automount live-proof (existing [ready] rows — safe once no deploy waiter is armed).
8. projects-subvol runbook Phase F sync (docs/services/projects-subvol.md burn-in still shown open).
9. Gatus ack: "Projects subvol backup leg stale" (fires by design until the catch-up lands).
10. Reboot-signature checklist → AGENTS.md session-discipline section (from §e.1).
11. If tonight 23:10 still refuses post-deploy (storm): the starvation slot (6h) + band 80 should self-catch-up when avg60 drops <50 — watch `memory_emergency_guard_backup_catchup_slots_total`.
12. Full `nix flake check --no-build` ride-along on the next CI push (selftests.nix change from the 14-03 session still unexercised beyond eval).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Session-26 SSH build battery (96 linkers, load 1050, freeze-#49 signature on the freeze-#54 recovery boot)**: yours (let it finish) or an autonomous dispatch (stop/pause it)? It is the current deploy blocker and the top freeze-#55 risk; TTY/SSH scopes are outside every gate and the 2026-10-07 license revocation forbids me SIGSTOPping them.
2. **cvagent**: leave stopped until its P0 fix session (recommended — nothing healthy was being served), or restart now and accept the 30–50 MB/s read storm returning mid-crisis?
3. **The shadow bundle** (from the 14-03 report, now with tmp evidence): confirm the 25G tmp sweep as dead weight, and rule on the shadow-cleanup tar.zst archive step (keep ~132G belt-and-suspenders vs skip the IO)?

---

*Arte in Aeternum — report waits for instructions; the deploy waiter stays armed.*
