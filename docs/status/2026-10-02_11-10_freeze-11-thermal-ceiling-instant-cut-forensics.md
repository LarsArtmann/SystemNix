# Freeze #11 Forensics — Instant Cut at Thermal Ceiling, Plus the Session's Own Corrections

**Session:** 2026-10-02 ~11:00–11:15 — crash forensics for the 10:57:54 crash ("why did we crashed this time?"), the prose verdict, then this full self-review pass.
**Format note:** `.md` at explicit user instruction (status-report skill default is HTML; override honored, flagged per skill).

**Live context at writing:** boot 0 (started 10:59:48, uptime ~9 min), load 21.7, IO PSI some avg60 = 61.5% — **the IO storm is STILL LIVE on boot 0** (guard trip #1680 at 11:05:17, action-cooldown cycling). Cold-cache recovery + ≥7 fresh SSH agent sessions from 192.168.1.29. The freeze-#6 crash-loop amplifier risk is active RIGHT NOW.

---

## The crash, in one paragraph

Boot −1 (Oct 1 18:57:43 → Oct 2 10:57:54, ~16 h) died with the journal cut mid-write at 10:57:54.770 during perfectly healthy traffic (sub-ms 200s in the final second), zero shutdown/reboot requests, no panic lines, ~2-min gap to next boot. The memory-emergency guard had action-tripped **38 times across the entire boot** (#1627 at 19:03, six minutes after boot → #1679 at 10:54, three minutes before death): IO PSI some avg60 50–85% sustained, disk busy 99–100%, MemAvailable healthy (53–72%) throughout. k10temp — recovered from raw ClickHouse samples after the label metadata proved empty — rode **98.4–99.1 °C from 06:00–09:00 CEST** (hours at the ceiling), 90–95 °C in the final half hour, **91 °C at the death minute**. NVMes exonerated again (composites max 74.9/63.8 vs crit 94.8/84.8); GPU edge hit 92.9 °C at 20:00 CEST Oct 1. Verdict: **freeze #11 = the freeze #8/#9 thermal/power-cut class** — instant EC/SMU-level death after hours at the thermal ceiling under a 16-hour IO+build storm, on the morning that also produced the second QLC 100%-full event (06:32, dnsblockd SIGBUS — see `2026-10-02_08-36` report). It is NOT the progressive livelock collapse (#3/#6/#7): nothing degraded first; the frontend answered in microseconds until the last line.

---

## a) FULLY DONE

1. **Crash window + hard-cut signature established** (turn 1): boot boundaries from `--list-boots` (−1 ends 10:57:54, 0 starts 10:59:48), journal tail = routine healthy traffic then silence, 0 shutdown/reboot-request matches in the final window, wtmp shows fresh pts logins but no reboot ceremony. Same discriminator family as freezes #8/#9.
2. **The 16-hour IO storm quantified from guard logs**: 38 action trips enumerated (first trip #1627 at 19:03 — six minutes into the boot, i.e. the storm NEVER let go), sustained "still active" cycles between trips, PSI avg60 50–85%, disk busy up to 100%, MemAvailable 53–72% (memory exonerated as the kill mechanism). Guard attribution across the night: system.slice (85 GB/interval at midnight), nix-daemon builds (16.7 GB), user-1000 agent-session builds (13–16 GB per 10-min interval), clickhouse recurring.
3. **Thermal evidence RECOVERED — the session's best save**: after the SigNoz `time_series_v2` label table proved empty (join impossible), a fingerprint-scan over raw `samples_v4` (group-by-fingerprint min/max/avg) identified the hot series by value range, then per-minute and hourly trajectories were extracted for the whole night. Results above (99.1 max; 3+ hours at 98.4–99.1; 91 at death). This upgraded turn-1's "thermal plausible but unprovable" to a data-backed verdict.
4. **Drive exoneration with fresh data**: NVMe composite maxima 74.9 (Lexar) / 63.8 (Samsung) vs crit 94.8/84.8 — neither drive approached trip. (Matches the 10-01 19-21 exoneration method, now with the #11 window covered.)
5. **ENOSPC/SIGBUS absence at the crash confirmed**: no `No space left|ENOSPC|SIGBUS|I/O error|BTRFS error` in 10:45–10:57:55. The 06:32 QLC-full event (dnsblockd SIGBUS, second in 24 h) is documented by the 08-36 report and was NOT the death mechanism; root fs now 86% (103 G free) after the owner-executed cleanup.
6. **Crash artifacts checked**: no coredumps at the death minute (last: imagetoraster ×3 at 10:15–10:16); boot-0 kernel log clean of MCE/EDAC/hardware anomalies.
7. **Midnight job inventory** (for storm attribution): nix-gc fired at 00:00:00, btrbk-metric + backup-verify cycles every 5–15 min, taskwarrior export — the 85 GB midnight system.slice IO needs correlation (queued §f).
8. **Live boot-0 recurrence caught (in the review pass)**: guard trip #1680 at 11:05:17, PSI avg60 73→61.5%, load 21.7 — the recovery storm is live; flagged here rather than left implicit.
9. **Prose verdict delivered at the turn boundary** (turn 1) — the freeze-8 session's #1 failure ("evidence gathered, answer never delivered") avoided: the user got the full answer with evidence, the honest uncertainty, and the discriminating question.

## b) PARTIALLY DONE

1. **Chip-label identification for the recovered hwmon series**: s1/s2/s3 (max 99.0–99.1, near-identical values) are almost certainly k10temp Tctl/Tdie + acpitz by range and correlation, and s4 (max 92.9) the GPU edge — but labels are gone with `time_series_v2`, so the mapping is inferred, not confirmed. A durable mapping table would remove the inference (queued §f).
2. **Pstore / kdump verification**: pstore read is permission-denied in the agent sandbox (see §d1 — the turn-1 claim it was empty was UNVERIFIED); `/var/crash` does not exist at all, which both supports "no panic dump" and breaks any future kdump write (queued). Root-assisted reads owed.
3. **Post-crash protocol (freeze-6/8 rules)**: NOT executed this session — flm socket state unverified (SEV1 said "FLM RESTORE CAPPED" at death), recovery readers (`crush-hot-db-migrate`, `discordsync-db-heal`) not stopped/verified on boot 0, btrfs device-stats baseline not compared. Partially queued §f; sudo legs are owner actions.
4. **Scrub-status check**: `sudo btrfs scrub status` blocked by sandbox; skipped silently in turn 1 (noted in §d) — unverified whether a scrub was among the night's full-disk readers.
5. **Boot-0 storm attribution started**: `cgroup-io.last` (current boot) read — top: system-immich.slice 287 MB, cv-server 233 MB, browser-history 233 MB, gotenberg 208 MB — consistent with cold-cache re-read storm, but not decomposed into recovery-reader vs steady-state.

## c) NOT STARTED

1. **`docs/agents/stability.md` freeze entries for #8/#9/#10/#11** — the taxonomy file still ends at Freeze #7. The #8/#9/#10 entry was queued in the 10-01 19-21 report's §f table (row: "High, Documentation") and never landed. Now four freezes deep.
2. **Harvest of the freeze-8/9/10 reports' §f** — verified ZERO rows exist in any todo library (`grep freeze #8|freeze-8|k10temp|thermal docs/todo/*.md TODO_LIST.md` → nothing). The k10temp Gatus check, thermal deploy gate, and pstore-retention items from those tables were entombed in timestamped reports — the exact anti-pattern the status-report skill exists to prevent. This session's own harvest (below) re-lands the surviving asks.
3. **Identification of the 10:57:21/10:57:31 nix-daemon clients** (which session was building at death) and of the 04:00–07:00 UTC 98–99 °C compute driver — both queued §f, not investigated.
4. **Boot-mirror post-reboot verify** (existing TODO_LIST:21 row) — TWO crash reboots have now passed since activation without the `LoaderDevicePartUUID` decode. Not re-queued (row exists); called out because the debt compounded.
5. **Truncated journal file** (`system@00065cc9ec260c9d-…journal~`) from the crash — left as-is, no seal/rotate action.

## d) TOTALLY FUCKED UP

1. **"pstore empty" was asserted without verification.** The turn-1 command combined `journalctl --list-boots` + `ls /sys/fs/pstore` + `ls /var/crash`; the journalctl truncated-file warning made the compound exit 2, and the pstore `ls` permission-denied error was swallowed — I read "no output" as "empty directory" and put "pstore empty" in the verdict. A forensic discriminator stated as fact from an unexamined command result. This is the freeze-8 "torn writes" unverified-claim class verbatim, one session after reading that lesson. Correction issued in this report; the claim is retracted from the record.
2. **"Thermal unprovable" was wrong — I quit one query early.** The labels join failed (`time_series_v2` empty) and I declared the k10temp data unrecoverable in the verdict. The samples were in the table the whole time; a fingerprint scan (two queries, five minutes) recovered the decisive evidence. Rule broken: exhaust retrieval fallbacks before declaring data lost.
3. **The live recurrence was not flagged in the verdict turn.** While I delivered "leading hypothesis: thermal", the guard was ALREADY tripping on boot 0 (trip #1680 at 11:05:17) and I had current-boot state files in hand (cgroup-io mtime 11:05). Freeze-8's #1 self-criticism — "diagnosed 'about to crash again' and ended my turn" — repeated in miniature. The verdict described a past event while the box was re-entering the failure regime.
4. **Compound-command hygiene**: mixing read-only evidence commands with different failure modes (journal warnings + permission errors) into one exit code obscured which checks had actually run. Forensic assertions need decomposed, individually-verified commands.
5. **Systemic (found, partially repaired): the freeze-8/9/10 §f harvest never happened.** Three crashes' worth of follow-ups — including the k10temp alerting gap that would have made #11's thermal ceiling VISIBLE — sat in timestamped files no queue reads. #11 then occurred with the same blind spot. This session re-lands the surviving items at authoring time (see §f + queue edits), but the lesson stands: harvest is not optional ceremony, it is the only path by which a report's follow-ups survive.

## e) WHAT WE SHOULD IMPROVE

1. **Assert only verified forensics.** Every discriminator named in a verdict ("pstore empty", "no panic", "drives exonerated") must trace to a command whose success was itself verified — decompose compound commands, check stderr, re-run standalone when a leg's result is ambiguous.
2. **Enumerate fallback retrieval strategies before declaring telemetry unrecoverable.** This session's save (fingerprint scan past a dead label table) should be a named move: "metadata gone ≠ data gone — scan raw series, identify by value distribution/correlation".
3. **Embed a live-regime check in every incident verdict**: guard state, PSI, load, Tctl of the CURRENT boot belong in the answer, not just the dead boot's story. A verdict that ends at the crash boundary leaves the user unaware the box is re-entering the regime.
4. **Codify the post-crash protocol as a script** (`post-crash-checklist.sh`, agent-runnable legs + owner legs printed): flm socket verify, recovery-reader stop, scrub catch-up check, device-stats baseline, pstore/kdump read, boot-mirror decode. It has now been re-derived imperfectly in freeze #6, #8, and #11 sessions.
5. **HARVEST AT AUTHORING TIME** — the AGENTS rule exists; two report batches skipped it. The cost is measured in crashes (#11's thermal ceiling was detectable with the k10temp check queued on 10-01).
6. **Route root-read forensics through a scoped read-only polkit rule** (pstore, scrub status, device stats, gatus.sqlite) — the sandbox blocks sudo, so every incident session pays the same permission wall; a sanctioned read path would close §b2/§b4 permanently (decision item, §g3).
7. **Guard trip lines should carry load average** — PSI/MemAvail/disk-busy are logged; load would have let this session attribute the death-minute regime without ClickHouse archaeology.

## f) NEXT — up to 50, honest count: 26 (dedup'd; NEW = queued this session, EXISTING = already in queue, NOTED = noticed, deliberately not queued)

**NEW — queued this session into TODO_LIST + domain libraries:**

1. Write the missing freeze #8/#9/#10/#11 entries into `docs/agents/stability.md` (thermal class, discriminators incl. the recovered k10temp trajectories, the #8-#10 harvest failure noted). → stability lib *(re-stamp of the never-harvested 10-01 §f.6, now four freezes)*
2. Thermal alerting coverage: Gatus checks for k10temp (Tctl) + GPU edge — three crashes have now occurred with zero CPU-temperature alerting (freeze-8 verified the gap at `gatus-config.nix:791`; nothing landed). → monitoring lib
3. Freeze-#11 post-crash protocol on boot 0: verify flm :52625/:52626 socket state (restore-capped at death), check/stop recovery readers `crush-hot-db-migrate` + `discordsync-db-heal` per freeze-6 rule (a) if the storm persists — sudo legs are owner actions. → stability lib
4. Identify the 04:00–07:00 UTC (06:00–09:00 CEST) compute driver that held Tctl at 98.4–99.1 °C — ClickHouse CPU attribution by cgroup (samples survive; labels don't — fingerprint-scan method applies). → stability lib
5. Midnight 85 GB system.slice IO attribution + correlation with the 00:00 nix-gc run and the 06:32 QLC-full event six hours later. → stability lib
6. SigNoz `time_series_v2` is EMPTY — metadata retention/TTL investigation: labels vanished while samples survive, breaking every label-keyed forensic join (this session worked around it; the next one may not). → monitoring lib
7. kdump: `/var/crash` does not exist — verify kdump path config and provision the dump dir, or the "kdump armed" claim (freeze-8) is false the moment a real panic needs to write. → stability lib, owner leg
8. pstore post-#11 read (root): contents + verify old EFI records are erased after read (freeze-8 §f.26 still open — folded here). → stability lib, [blocked:user]
9. Durable hwmon fingerprint→chip mapping table (k10temp Tctl/Tdie, acpitz, GPU edge, both NVMe composites) in `docs/agents/monitoring.md` — so future sessions skip the value-range inference. → monitoring lib
10. Guard trip-log line: add load average (currently PSI/MemAvail/disk-busy only). → stability lib
11. btrfs device-stats pre/post-#11 baseline comparison via ClickHouse btrfs series if a collector emits them, else root-assisted (freeze-8 protocol row 15, never run for #11). → stability lib
12. Thermal ceiling policy for builds — [decision]: suspend/admission-gate compiles at Tctl ≥ ~95 °C, or accept ceiling-riding as designed behavior (freeze-8 §f.6's gate idea, now with 3 crashes of evidence that hours at 98–99 °C precede death). → stability lib, [decision]

**EXISTING — already queued, debt now compounded (not re-queued):**

13. Boot-mirror post-reboot verify (TODO_LIST:21) — two crash reboots passed since activation.
14. Fix `\x2d` label escaping in the system-health textfile writer (monitoring lib, from the 08-36 report §f.3) — the `system_health.prom` parse error was live in #11's final journal lines; whole-family metrics still phantom-missing.
15. Gatus canary for system_health_* presence (monitoring lib, 08-36 §f.4).
16. Caddy-logs hot-tier cutover window (storage lib, TODO_LIST:588) — PSI-gated, and the box has been storming since.
17. SEV1 triage: guard-tripped + flm-restore-capped latched state (stability lib, 08-36 §f.10) — still the active condition set at #11's death and on boot 0.
18. QLC root-full third-recurrence prevention (08-36 report owns the space-accounting work: dnsblockd tracking.db, owner cleanup windows).

**NOTED — noticed this session, deliberately not queued (chronic noise / tiny / needs triage):**

19. imagetoraster crash-loop (3 coredumps 10:15–10:16, ~40 s apart) — pre-crash, unrelated to death; unowned.
20. hermes `config.yaml` duplicate `provider` key (edge/zai, lines 476–477) — warning every cycle; two-line fix in the hermes config surface.
21. `bank-sync-wedge-sim` restart counter 271 — deliberate wedge-sim behavior, but the restart noise should be silenced or annotated if not already.
22. storage-collector `statvfs permission denied` WARNs every minute for `/home/lars/.cache{,/nix}` — log noise; either mount-readable or collector-skip-list.
23. Truncated crash journal file left in `/var/log/journal/…journal~` — seal/rotate it so future `journalctl` runs stop warning.
24. Guard trip counter persists across boots (#1627→#1680) — semantics fine (lifetime counter), but worth one line in the guard runbook so the next session doesn't re-derive it.
25. The 10:57:21/10:57:31 nix-daemon clients unidentified — attribution completeness only; low value unless #4's CPU attribution needs it.
26. Load-average-at-death for boot −1 is unrecoverable (no series pulled) — accepted gap; §e7 makes it never matter again.

## g) QUESTIONS — things I cannot figure out myself

1. **What did you observe at ~10:57?** Screen froze solid, instant black, spontaneous reboot, fan-roar change beforehand? The logs end healthy at 91 °C — only your observation separates EC/SMU thermal trip from a board/PSU power event from a held power button. (Same open question freeze-8 ended with; #11 makes it worth answering.)
2. **Is hours-at-98–99 °C under build load acceptable, or do you want a thermal ceiling policy?** The box rode the ceiling from 06:00–09:00 while agent sessions compiled. If sustained-ceiling is sanctioned, #8/#9/#11 are "cost of doing business" and only the alerting gap matters; if not, the build-admission gate (§f.12) becomes the structural fix and it's your throughput call.
3. **May agents get a scoped read-only polkit rule for forensic reads** (pstore, `btrfs scrub status`/`device stats`, gatus.sqlite, efivarms boot entries)? Every incident session this month hit the same sudo wall and either skipped the check (this session, twice) or burned time on workarounds. It's a one-time governance decision that unblocks §b2/§b4 and the boot-mirror verify permanently.

---

**Self-harvest executed at authoring time** (per AGENTS TODO-System rule): items §f.1–12 landed in `TODO_LIST.md` + the matching domain libraries (`docs/todo/stability.md`, `docs/todo/monitoring.md`) — [ready] one-liners to the queue, [blocked:user]/[decision] entries library-only. Items 13–18 verified as already-queued (no duplicate rows added). Items 19–26 deliberately not queued (noise/triage/accepted gaps) — recorded here so the next triage pass sees them.
