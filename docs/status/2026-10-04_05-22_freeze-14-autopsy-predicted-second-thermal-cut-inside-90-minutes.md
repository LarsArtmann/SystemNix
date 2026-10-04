# Freeze #14 Autopsy — The Predicted Second Thermal Cut, 88 Minutes After the #13 Report (2026-10-04 05:07)

**Session:** 2026-10-04 ~05:09 → ~05:25 — single-question session ("Why we crashed now?"): prose verdict delivered at the turn boundary FIRST, then this report + the mandated harvest. Read-only forensics, no deploys, no service actions (agent sandbox blocks sudo/systemctl — owner legs flagged in the Live section).

**Sibling context:** freeze #13 autopsy (`2026-10-04_03-50`) — this crash is that report's explicit live prediction ("**Freeze #14 risk is live at authoring**: Tctl 99.1 °C / PPT 118.3 W / load 38.8 / IO PSI avg60 61 %") landing **88 minutes** later. Freeze #12 autopsy (`2026-10-03_14-23`) and the storm/anchoring session (`2026-10-04_03-05`) document the regime.

## Verdict

**Freeze #14 = the thermal-ceiling instant-cut family (#8/#9/#11/#12/#13), second cut inside 88 minutes, on the SAME standing cooling deficit — the box never cooled after #13.** Boot -1 (Oct 04 03:37:55 → 05:07:41, 1h30m) re-entered the storm immediately: its FIRST guard trip at 03:40:54 (3 min after boot) already carried the recovery-read storm (hermes +2,528 MB, boot fsck +247 MB, discordsync +133 MB), and the #13 report's own live probe at 03:46 read Tctl 99.1 °C / PPT 118.3 W. Nine trips (#1812-dup → #1820) cooldown-cycled the whole short boot; trip #1820 (05:01:12) measured **user.slice +17,453 MB / user-1000.slice +17,391 MB / system.slice +15,516 MB** top-IO — a whole-box storm. In the final 8 seconds a **nix eval/build burst hammered nix-daemon at dozens of connections/second** (pids 3,077,174→3,081,363, user lars, NO deploy unit activity anywhere in the window) — a direct violation of the #13 report's "NO heavy builds until the cooling inspection" gate, driver unidentified. At 05:07:41.14 the journal cut mid-traffic (nsfw-server readyz 200, ms-latency requests throughout the final minute) with zero shutdown ceremony, zero OOM-kill/MCE/btrfs error lines in the entire boot. The kill mechanism is the same thermal/EC instant cut; the storm (nix burst + recovery readers + SEV1 latch cycling every 10 s) was the heat load that rode the deficit to the ceiling. Boot 0 minutes later: **Tctl 81.5 °C at only PPT 46.4 W** (near-idle — the deficit now holds a crash-sustaining temperature at idle-ish power) and **IO PSI some avg60 80.2 % — higher than #13's death trip (64.4 %)**: freeze #15 conditions were already forming while this report was written.

## Evidence

| # | Finding | Evidence |
|---|---------|----------|
| 1 | Hard cut, no ceremony | journal cuts 05:07:41.14 mid-traffic; `last -x` shows zero shutdown entries between the 03:38 and 05:09 boots |
| 2 | Healthy-to-silence < 1 s = instant-cut discriminator | last line nsfw-server `/readyz` 200 at 05:07:41.140; cv/inboxclean/geometrikks requests at ms latency through 05:07:38; no escalating stall cascade |
| 3 | Not OOM, not storage, not hardware-error | kernel scan of boot -1: zero OOM-kill lines, zero MCE/EDAC, zero BTRFS error lines |
| 4 | Guard + SEV1 active to the last second | SEV1 bridges 05:07:18 → :28 → :38 ("MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED"); guard unit ran 05:07:11; trip #1820 (05:01:12) = the whole-box IO numbers above |
| 5 | Death-minute nix storm, driver UNIDENTIFIED | 3,014 nix-daemon accepted-connection lines in the 1h30m boot; dense burst (dozens/sec) 05:07:33–38; no switch-to-configuration/nixos-rebuild/nh lines in the window; pids gone at autopsy — gate violation regardless of who |
| 6 | btrfs: no new error events | kernel-log scan of BOTH boots: zero BTRFS error lines. Weaker than the #13 mount-counter protocol — sysfs devstats not readable from this sandbox (glob no-match), stated as run |
| 7 | Thermal deficit live on boot 0 | 05:14: Tctl 81.5 °C @ PPT 46.4 W, load 2.7 — near-idle power holding near-throttle temperature; zero fan telemetry (same as freeze-12 probe) |
| 8 | Storm INTENSIFIED on boot 0 | IO PSI some avg10 75.2 / avg60 **80.2** / avg300 47.1 at 05:14 — vs 61 % at #13-report authoring and 64.4 % at its death trip |
| 9 | Guard trip-counter continuity HELD this cut | boot -1 last persisted trip #1820 (05:01:12) → boot 0 first trip #1821 (05:15:32, top IO fsck +232 MB) — no duplicate-counter anomaly; no action-trip occurred between 05:01 and the power cut, so nothing was lost |
| 10 | Panic-dump discriminators still unavailable | `/var/crash` still ABSENT (kdump row stability.md:106, open since freeze-8); pstore unreadable from the agent sandbox (stated unreadable, NOT empty) |
| 11 | Thermal alerting STILL dark | fifth thermal-family crash with zero CPU-temperature alerting (monitoring.md:17 + :79, open since 10-02) |
| 12 | Death-adjacent forensics bundle SURVIVED this time | `/var/tmp/io-psi-forensics-20261004T030111Z` exists (trip #1820's bundle); boot-0 trip bundle 031532Z also present — the #13 013546Z vanish (finding 9 there) did not recur, but the durability fix row stands |
| 13 | niri tty flood ABSENT in both latest boots | `early import: Error::DeviceMissing` = 0 lines in boot -1 AND boot 0 (140,411 lines in the 10-03 14:15 boot) — desktop row stays open but is not reproducing on these two boots |

## Live regime at authoring (freeze-8 rule: verdicts carry current-boot state)

- **Tctl 81.5 °C / PPT 46.4 W / load 2.7 / IO PSI some avg60 80.2 %** at 05:14 — the box is re-entering the death regime at near-idle power; the storm is the strongest yet measured post-crash.
- **Owner actions that cannot wait for a queue cycle:** (1) the physical cooling inspection (row stability.md:117) — it is now the documented direct kill mechanism of TWO crashes inside 88 minutes, and the deficit holds 81.5 °C at 46 W idle-ish load; (2) IO PSI avg60 is ≥ 60 (it is 80): stop the recovery readers `crush-hot-db-migrate` + `discordsync-db-heal` per freeze-6 rule (a) — sudo legs, row stability.md:103 already carries the ask; (3) identify and stop the 05:07 nix-eval driver if it is a recurring daemon (tq fleet / auto-commit daemon / cron) — it ran against an explicit written gate.

## a) FULLY DONE

1. **Full autopsy with every discriminator answered** (table above); verdict delivered in prose at the turn boundary BEFORE this report (freeze-12 §d.1 lesson), with live-boot state embedded (freeze-11 §e.2 lesson).
2. **btrfs pre/post comparison executed at kernel-log-scan strength** — zero error lines both boots; the weaker method vs #13's mount counters is stated, not overstated (row stability.md:109 updated).
3. **Guard counter continuity verified across the cut** — #1820 → #1821, no duplicate (row context updated on the existing persist-before-log queue row).
4. **§f self-harvest at authoring time** — stability.md rows 102/109/117 updated, one NEW ready row queued on both surfaces, `scripts/check-todo-system.sh` green after the edits.

## b) NOTICED, NOT DIAGNOSED (out of scope or owner-gated)

1. **The nix-eval driver identity** — pids gone, parent/cgroup not logged by nix-daemon's connection lines; candidates: tq-agent-pool fleet, the auto-commit daemon, an interactive session's flake check. Boot -1's journal is still warm for cgroup archaeology (queued, §f.1).
2. **storage-collector statvfs EPERM on `/home/lars/.cache{/nix}` every minute** — chronic pre-existing noise (also visible in freeze-13's window), noticed only.
3. **postgres `paperless` collation-version warnings repeating** — pre-existing, noticed only.
4. **mr-sync tile service.status down→up flap + "unhandled event" projection warnings** at 05:07:37 — noticed only; the projection-gap class is already a known surface.

## c) DELIBERATELY NOT DONE

1. **crash-autopsy.sh not written** (row stability.md:121 / TODO_LIST queue, queued since freeze-12) — this is the SIXTH manual protocol derivation (#6/#8/#11/#12/#13/#14); same mid-incident-tooling argument as #13 §c.1.
2. **No ClickHouse thermal-series forensics for boot -1** — the 1h30m boot almost certainly rode the ceiling, but running fingerprint scans mid-storm (PSI 80) to prove it adds load now for a verdict the live probes already carry; queued evidence, not run.
3. **No guard/module edits** — same deploy-gating argument as #13 §c.2.
4. **pstore / trip-history file reads** — sudo-blocked; reported as unreadable, never as empty.

## d) SELF-CRITICISM

1. **The nix-storm driver was not identified before the verdict was delivered** — the verdict (thermal cut) does not depend on it, but "who violated the gate" is the actionable half of the death minute and it is open.
2. **The devstats sysfs read failed quietly** (glob no-match) and was only noticed while composing the evidence table — the kernel-log-scan fallback is labeled with its weaker strength.
3. **No closing sensors anchor after the journal archaeology** — freeze-12 rule asks for sensors FIRST (done this time); a free closing anchor was skipped and the 05:14 reading is the only live thermal datum.

## e) IMPROVEMENTS

1. **Written gates are not enforcement.** The #13 report said "NO heavy builds" and a nix eval/build burst ran in the death minute anyway. Standing URGENT rows and gates need an admission mechanism (the IO-admission row and thermal-gate option (a), row stability.md:110, are the structural asks), not more prose.
2. **Two cuts inside 88 minutes change the failure model**: the deficit is now crash-sustaining under near-idle load (46 W) — the box cannot be treated as "stable between storms" until the physical inspection happens.
3. **The #13→#14 prediction-to-reality gap is now measured in minutes, not days** — the same escalation lesson as #13 §e.1, one notch worse: the risk was named in writing, live, and the box died before the next queue cycle could even dispatch.

## f) HARVEST (at authoring time — all landed)

1. **[NEW stability, ready]** Identify the 05:07:33–38 nix eval/build driver (3,014 nix-daemon connections across the 1h30m boot, final-8s burst at dozens/sec, pids 3.07M range, no deploy units in the window) — tq-agent-pool vs auto-commit daemon vs interactive flake check; then give the no-heavy-builds gate an enforcement leg (admission/hook) so the next gate violation is prevented, not autopsied. → TODO_LIST + stability.md
2. **[UPDATED stability:102]** freeze-taxonomy row extended: entries #8–#13 → #8–#14 (1h30m boot, 9 trips #1812-dup→#1820, instant cut mid-traffic, kernel-scan btrfs clean, death-minute nix burst unidentified).
3. **[UPDATED stability:109]** btrfs-baseline row: #14 comparison RUN at kernel-log-scan strength — zero BTRFS error lines in both boots; devstats sysfs unreadable from sandbox (weaker than the #12/#13 mount-counter protocol, stated).
4. **[UPDATED stability:117]** the cooling row: bait taken TWICE — #14 landed 88 min after the #13 report predicted it; deficit live at Tctl 81.5 °C @ PPT 46.4 W near-idle on boot 0; inspection gates all heavy builds.
5. **[NEW evidence to EXISTING rows, no new ask]** monitoring.md:17/:79 (thermal alerting — FIFTH dark crash), stability.md:103 (recovery-readers stop trigger: PSI avg60 is 80 %, well past the ≥ 60 threshold — owner leg live NOW), stability.md:121/TODO_LIST crash-autopsy.sh row (sixth manual pass), TODO_LIST guard-counter persist row (continuity held across THIS cut — no duplicate, because no action-trip followed 05:01; the fix ask unchanged), desktop niri-flood row (0 lines both latest boots — not reproducing, row stays).
6. **Deliberately NOT harvested:** the SEV1 live-vs-latched question (row stability.md:100 — #14's SEV1 lines show the latch cycling, adds no new ask beyond that row), hermes duplicate-key (services.md:20, unchanged), IO-admission row (stability queue — cited in §e.1 as the structural fix, already open).

**Bottom line for the owner:** the box died the same death twice in 88 minutes, the second time exactly as predicted in writing — heat it cannot shed at ANY load level (81.5 °C at 46 W idle-ish minutes after reboot), under a storm that is now stronger than at #13's death (IO PSI avg60 80 %). The cooling inspection is the only action on the critical path; second is stopping the recovery readers now (PSI trigger long passed); third is finding what ran the nix eval burst against the written gate.

