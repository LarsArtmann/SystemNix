# Freeze #16/#17 Autopsy — thermal-pstate-guard Throttled Through Both Cuts; the Family Is Unbroken (2026-10-06)

**Session:** 2026-10-06 ~15:16 → ~15:30 — trigger: user asked "Why did we crash?" after the 15:14 boot. Read-only forensics (agent sandbox blocks sudo — pstore/btrfs-counter legs owner-gated). Autopsy of the 10-05 19:41:16 cut (#16) and the 10-06 15:12:57 cut (#17); no module edits (everything candidate is a standing row; see §c).

**Sibling context:** freeze #13 autopsy (`03-50`), #14 (`05-22`, predicted #15), #15 (`09-15`, predicted #16 — "Freeze #16 is loading while this report is written": it landed 34 h later, survived an interposed calm-ish day, then recurred 19.5 h after that). Two additional cuts confirmed this session beyond what the user asked about: none — #16/#17 ARE the two abrupt cuts since #15; the 10-05 10-15 → 13-52 deploys rode reboots inside boot -2's window without journal cuts.

## Verdict

**Freezes #16 and #17 = the thermal-ceiling instant-cut family, now crashing WITH the deployed mitigation active — guided-governor throttling does not close a standing physical cooling deficit.** thermal-pstate-guard went live 10-04 10:47 (first `THERMAL THROTTLE ENTER`, boot -2) and was cycling/holding `amd_pstate -> guided` across BOTH dead boots: 7 throttle ENTERs in #16's 34 h boot, 4 in #17's 19.5 h boot — and #17's guard samples read ≥95 °C in 58 of 61 ticks (96–99 °C, 19:57 → 15:04, the last 8 minutes before the cut). The guard did its job; the ceiling held anyway. Both journals cut mid-traffic with sub-second-healthy final lines (nsfw `readyz 200` at 19:41:16.609; bank-sync mid-WARN at 15:12:57.618), zero shutdown ceremony, zero OOM/MCE/BTRFS error lines in either boot — the #11 instant-cut discriminator, twice more.

The chronic IO storm ran both boots as the heat load: #16 = 125 Zone-6 trips #1846→#1970 with FLM restore-capped by 19:30 and SEV1 (`MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED`) latched 11 minutes pre-cut; #17 = 102 trips #1971→#2072, final two at avg60 83.3 %/79.2 % IO PSI with disk busy 100 % and MemAvailable 50–59 % (crash-#3-pattern numbers on a thermal-class cut). Guard counter continuity held across both cuts (#1970→#1971, #2072→#2073). **The physical cooling inspection (standing `[blocked:user]` row) has now been the predicted-and-ignored kill mechanism for seven cuts (#8/#9/#11–#17); the newly-proven fact this session is that the software mitigation layer cannot substitute for it.**

## Evidence

| #  | Finding                                                        | Evidence                                                                                                                                                                                                                                                                           |
| -- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | #16 hard cut, no ceremony                                      | boot -2 (Oct 04 09:32:34 → Oct 05 19:41:16, 34 h 08 m) ends on nsfw `readyz 200` at .609 — healthy ms-latency traffic to the last line; boot -1 starts 19:41:44                                                                                                                    |
| 2  | #17 hard cut, no ceremony                                      | boot -1 (Oct 05 19:41:44 → Oct 06 15:12:57, 19 h 31 m) ends mid-bank-sync-WARN (.618); the SEV1 stdio-bridge notify-session storm (sessions 16503–16509, one per ~100–300 ms) opens in the final two seconds — the same death-second signature as #13/#15                          |
| 3  | Guard throttled THROUGH both cuts                              | `thermal-pstate-guard:` lines live in both dead boots; ENTERs at Oct 04 10:47/95 °C, Oct 05 01:22, 02:00, 09:55, 10:51, 14:33, 18:23 (boot -2) and Oct 05 19:57/98 °C, Oct 06 01:40, 03:57, 13:30 (boot -1); #17 rode 96–99 °C on 58/61 ten-minute samples                         |
| 4  | Storm = both boots' background                                 | #16: trips #1846 (early Oct 04) → #1970, 125 Zone-6 trips; #17: #1971 → #2072, 102 trips at ~10–11 min cadence                                                                                                                                                                     |
| 5  | #16 pre-death latches                                          | FLM restore capped (3/3) at 19:30:16 and again 19:40:20; SEV1 notify active `2 conditions` at 19:29:59–19:30:10 — 11 min before the cut                                                                                                                                            |
| 6  | #17 death-window regime                                        | trip #2071 14:57:17 (avg60 83.28 %, disk 100.0 %, MemAvail 58.8 %; top IO system.slice +16,292 MB, user-1000 +10,241 MB) and #2072 15:07:20 (79.20 %, 97.5 %, 49.8 %; +12,739/+9,824 MB); cooldown heartbeat 15:04:49; guard check ran clean to 15:12:52 — live to the last second |
| 7  | Not OOM, not storage, not hardware error                       | kernel scan boots -1/-2: OOM-kill 0, MCE/EDAC events 0, BTRFS error lines 0 (kernel-log strength only — sysfs devstats unreadable from this sandbox, same as #14)                                                                                                                  |
| 8  | Guard counter continuity HELD twice                            | #1970 → #1971 across the #16 cut; #2072 → #2073 across the #17 cut — no duplicate-counter anomaly                                                                                                                                                                                  |
| 9  | Thermal range spanned the whole day, not just load peaks       | boot -2 samples include 95–99 °C from 10:51 through 18:26; boot -1 never released below the re-entry band for >3 h at a time                                                                                                                                                       |
| 10 | pstore NOT verifiable from this sandbox                        | `/sys/fs/pstore/`: Permission denied — the standing root-read row applies; earlier conversational "pstore empty" in this session was WRONG and is retracted here (same unverified-claim class freeze-15 §d flagged)                                                                |
| 11 | The a7868a7 deploy + one generation switch rode INSIDE boot -2 | exactly 1 switch-to-configuration line in boot -2 — the 10-05 vendorhash-wave deploy (report `10-15`, "deploy-pending") landed mid-boot between #16's throttle cycles; it did not itself cut the boot                                                                              |

## Live regime at authoring (freeze-8 rule: verdicts carry current-boot state)

- **Boot 0 is 10 minutes old and already storming: trip #2073 fired at 15:17:38 (3 min in, Zone 6); IO PSI some avg10 67.4 / avg60 65.0; load 34; Tctl 83.8 °C / acpitz ~85 °C climbing at load 34.** Two thermal-pstate-guard ticks already logged. Freeze #18 conditions are forming at authoring — the third consecutive autopsy to say so while writing itself (#14 → #15 → this).
- Owner actions that cannot wait (unchanged from #13–#15, now with two more corpses as evidence): (1) the physical cooling inspection — the guided throttle provably cannot hold the ceiling; (2) shed load on the live boot (load 34 at Tctl 84 °C on a 10-minute-old boot).

## a) FULLY DONE

1. Full #16+#17 autopsies with all portable discriminators answered (table above); both classified thermal instant-cut family on the standing deficit.
2. NEW discriminator answered: mitigation-present crash — thermal-pstate-guard live and throttling in both dead boots; effectiveness verdict recorded (insufficient as a standalone fix).
3. Guard counter continuity verified across both cuts; kernel OOM/MCE/BTRFS scans clean on both dead boots.
4. Retracted this session's own unverified "pstore empty" claim inside the report (finding 10) rather than letting it age into a cited "fact".
5. Crash-era timeline extended: Oct 4 03:36 (#13), 05:07 (#14), 08:38 (#15), Oct 5 19:41 (#16), Oct 6 15:12 (#17) — five cuts in ~84 h, all one family.

## b) NOTICED, NOT DIAGNOSED

1. The final-2-seconds stdio-bridge session storm in #17 — assumed the SEV1 notify mechanism per #13/#15's identification; per-command attribution not re-derived this session.
2. Trip-attribution granularity stopped at slice level (system/user-1000); the scope-level decomposition (freeze-15 §e.4 ask: top-N session scopes in the trip line) is still not implemented, so the #17 death-minute container is NOT identified — one grep away only after that row lands.
3. Boot -2's calm stretch (deploy window 10-05 10-15 → 13-52 completed) shows the storm CAN drain for hours without a cut — the deficit kills under sustained load, not instantly; no action taken.

## c) DELIBERATELY NOT DONE

1. No ClickHouse thermal series extraction (samples_v4 fingerprint-scan) — same mid-storm cost argument as #14 §c.2/#15 §c.1; the 10-minute guard samples already carry the ceiling.
2. No btrfs device-stats pre/post comparison (root-gated; kernel-log-clean stands as the weaker proof) and no pstore read — standing owner-gated rows.
3. No guard/module edits — the candidate changes are the standing thermal-policy/coverage rows; mid-storm surgery would need the very builds the gate forbids.
4. crash-autopsy.sh still unwritten — NINTH manual derivation (#6/#8/#11/#12/#13/#14/#15 + #16/#17).

## d) SELF-CRITICISM

1. **I asserted "empty pstore" in the pre-report answer from a swallowed-error compound command** — the exact failure mode the standing `[blocked:user]` pstore row documents (turn-1 and freeze-12 both burned by it). Corrected in-report; the live conversational record now carries the retraction.
2. One backgrounded grep batch silently typo'd a journalctl flag (`--no-pervisor`), returning empty hot-sample evidence that briefly contradicted the visible 98 °C line — caught because the two probes disagreed, re-run clean. Lesson restated: never let a typo'd probe overwrite an observation you already have.

## e) WHAT WE SHOULD IMPROVE

1. **Mitigation effectiveness must be measured, not assumed deployed** — the thermal-pstate-guard deploy closed its `[blocked:deploy]` row, and two crashes later that is all it closed. Every mitigation row needs a post-deploy effectiveness criterion ("no ≥95 °C sample while throttled under load N" would have failed on day one).
2. Deeper throttle tier: guided at these loads holds 96–99 °C; the guard needs a second rung (frequency cap / EPP performance-floor drop / trip-triggered load shedding) or the honest label "deficit-masked, not mitigated" until the physical fix lands.
3. The prediction-to-cut loop is now 3 autopsies long (#14→#15, #15→#16, this→#18?) with zero owner-leg execution between; the enforcement row (nix/build admission gate) remains the only self-help leg and is still unlanded.

## f) NEXT THINGS (self-harvested at authoring; routed to queue/library per TODO rules)

1. **[ready] thermal-pstate-guard second throttle rung / effectiveness criterion** — NEW row (stability.md library + TODO_LIST queue): guided held 96–99 °C through two crash boots; add a deeper rung or re-label as deficit-masking. **Source:** this report §e.1/§e.2.
2. **[blocked:user] physical cooling inspection** — standing row EXTENDED: BAIT TAKEN a 4th and 5th time (#16, #17), first cuts WITH the guard throttling. **Source:** this report Verdict.
3. **[ready] Write the missing freeze #8–#13 entries** — standing row EXTENDED with #16/#17 draft material (this report Verdict + Evidence table). **Source:** this report.
4. **[ready] No-heavy-builds enforcement leg + scope-level trip attribution** — standing rows unchanged, each gaining this report's data point (load-34 boot-0 regime at authoring; slice-level-only attribution in finding 6).
5. **[owner/live] Shed load on boot 0** — not a queue row: trip #2073 + Tctl 83.8 °C at 10 min uptime; freeze-#18 conditions live NOW.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. Cooling inspection scheduling — now seven crashes deep, with the software layer proven unable to substitute.
2. Whether the second throttle rung (§e.2) should trade visible performance (frequency cap under ceiling) for crash avoidance until the physical fix — a UX-vs-uptime call only the owner can make.

**Standing state at report close:** freezes #16/#17 autopsied (thermal family, mitigation-insufficient class); guard counter continuity intact; storm chronic (boot 0 re-tripped in 3 min); thermal-pstate-guard deployed-but-insufficient; cooling inspection still the unexecuted kill-mechanism fix; freeze #18 conditions present at authoring.

_Arte in Aeternum_
