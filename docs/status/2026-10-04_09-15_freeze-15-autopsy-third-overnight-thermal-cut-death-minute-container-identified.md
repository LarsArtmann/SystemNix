# Freeze #15 Autopsy — Third Overnight Thermal Cut (08:38), Death-Minute IO Container Identified (2026-10-04)

**Session:** 2026-10-04 ~08:45 → ~09:15 — trigger: user asked "We crashed again?" after the 08:39 boot. Read-only forensics (agent sandbox blocks sudo/systemctl — owner legs flagged in §f). Autopsy of the 08:38:22 cut + the current-boot live regime; NO module edits (deploy-gated; the tq-churn question is a standing `[decision]` row and was deliberately not touched).

**Sibling context:** freeze #13 autopsy (`03-50`, the 03:36 cut), freeze #14 autopsy (`05-22`, the 05:07 cut — predicted this crash's conditions at its own authoring: "freeze #15 conditions were already forming"), soak-unblock session report (`08-32`, staged-but-then-deleted from the worktree — see §b.5), storm/anchoring session (`03-05`).

## Verdict

**Freeze #15 = the third overnight thermal-ceiling instant-cut (03:36 = #13, 05:07 = #14, 08:38 = #15), landing exactly in the regime freeze #14's report flagged while writing itself.** The box never cooled after #13 (Tctl 99.1 °C at 03:46 per #13; 81.5 °C at near-idle 46.4 W / load 2.7 on the post-#14 boot per #14 — a standing cooling deficit), and boot -1 (05:09:31 → 08:38:22, 3h29m) re-entered the chronic IO storm immediately: guard Zone-6 trips every ~10.5 min for the ENTIRE boot (#1821 at 05:15 → #1840 at 08:33), io PSI some avg60 89.3 % at the last two trips, and the 08:32 soak-unblock report's own live probe read **io PSI some avg10 = 91.77 %** — six minutes before the cut. At 08:38:22 the journal cut mid-activity (session scopes closing, SEV1 stdio-bridge notify sessions 3189/3190 opening at the death second) with zero shutdown ceremony, zero OOM-kills, zero actual MCE events, zero BTRFS error lines.

**New for this cut — the death-window's dominant IO container is IDENTIFIED: `session-259.scope`, the soak-unblock session itself (SSH from 192.168.1.29, 05:23:25 → death).** Guard attribution names it top IO in the final two trip windows (#1839: user-1000 +69,542 MB of which session-259 +60,982 MB; #1840: +67,461/+60,272 MB — the scope moved ~120 GB in the last ~21 minutes), and its sudo history in the same window is the workload mix: 3× `llama-rag-soak.sh` invocations, 13× `systemctl restart signoz-coverage-metrics`, 21× `btrfs subvolume list/show` walks of `/mnt/pool`, 6× deploy/deploy-tail invocations, and its own report describes three commit attempts whose pre-commit batteries run full `nix flake check` — the death window (08:32→08:38) shows 110 nix-daemon accepted-connections. This is the same class as freeze #14's unidentified death-minute nix burst (05:07:33–38): **interactive agent sessions running verification batteries (flake check / pre-commit / evals) are a recurring storm-completion driver** — and the class recurred AGAIN at this report's authoring (§ Live regime). The verdict (thermal instant-cut) does not depend on the container ID; the container is the actionable half.

## Evidence

| # | Finding | Evidence |
|---|---------|----------|
| 1 | Hard cut, no ceremony | journal cuts 08:38:22 mid-session-scope activity (sessions 3189/3190 stdio-bridges at :22); no shutdown/reboot targets; boot 0 starts 08:39:51 |
| 2 | Storm ran the WHOLE boot, worsening to the end | trips #1821 (05:15:32) → #1840 (08:33:06), ~10.5-min cadence, never draining below the re-arm threshold; last two trips avg60 = 89.27/89.29 %, disk busy 100 %, MemAvailable 50–58 % (the crash-#3 pattern numbers on a thermal-class cut — the storm is the heat load) |
| 3 | Not OOM, not storage, not hardware error | boot -1 kernel scan: OOM-kill lines 0; MCE/EDAC events 0 (single `EDAC MC: Ver: 3.0.0` banner at boot 05:09:43 is driver init, not an event); BTRFS error lines 0 |
| 4 | Death-window IO container = session-259.scope | trip #1839/#1840 attribution lines (08:23:03, 08:33:06): `user.slice +69,578 MB, user-1000.slice +69,542 MB, session-259.scope +60,982 MB` then `+67,461/+60,272 MB`; sudo COMMAND lines: soak ×3, signoz-coverage restarts ×13, pool subvolume walks ×21, deploy-tail ×6 |
| 5 | The 08:32 report measured the death approach | its §g.2: "IO pressure is extreme right now (some avg10=91.77 at 08:32, up from 52% at 07:43)" — monotonic climb through the soak session's own verification battery |
| 6 | Guard + SEV1 live to the last second | guard ran 08:38:07 (clean, no action — inside cooldown); SEV1 notify stdio-bridges opening at 08:38:22 = the cut lines themselves |
| 7 | Guard trip-counter continuity HELD | boot -1 last trip #1840 (08:33:06) → boot 0 first trip #1841 (08:44:54) — no duplicate-counter anomaly |
| 8 | Scrub catch-up amplifier FIXED and PROVEN | freeze-#7's queued `Persistent=false` + After=-chain landed 2026-10-01 `f21be80a` (snapshots.nix:947 + asDropin chain :534-541); ZERO `Starting Regular btrfs scrub` service lines across boots -3/-2/-1/0 despite 3 crashes — the timer-start lines at 08:40:07 are timer units, not fires. stability.md's "REMAINING (queued)" text was stale (corrected this session) |
| 9 | niri tty flood absent | 0 `DeviceMissing` lines in boots -1 and 0 (flood was boot -3 only: 140,411 lines — #14's finding 13 stands) |
| 10 | kdump STILL dark | `/var/crash` absent (standing row, open since freeze-8); pstore unreadable from this sandbox |
| 11 | io-psi-forensics bundles surviving, unpruned | 1,746 bundles in /var/tmp (retention row stands); boot-0 trip bundles present |
| 12 | tq-agent-pool bursts were the EARLIER storm's peak driver, idle at death | trip #1771 (Sat 14:35): +155,623 MB in ~20 min; trip #1798 (00:28): +261,479 MB in ~16 min — the standing `[decision]` guard-coverage row already carries this; at death the pool was budget-capped idle (32/30, harvest skips since boot) |
| 13 | The 03:46 raw `nh os switch` failed and bypassed every deploy gate | sudo line: `env PATH=…nh-4.4.2… switch-to-configuration` from pts/1 (session-3); "failed (status 4)" at 03:47:37 — failing unit: `forgejo-gen-runner-token` → gitea-runner crash-loop (ALREADY tracked, TODO_LIST:227 / services.md:19, since freeze-12); deploy.sh's zone-6 gate never saw this switch. A deploy.sh deploy followed at 03:51 into the active storm |

## Live regime at authoring (freeze-8 rule: verdicts carry current-boot state)

- **Tctl (k10temp) 76 °C / acpitz 85 °C / nvme 50+52 °C at load 22.9 / 46.0 (avg1/avg5)** — a parallel session is running **`nix flake check --keep-going` (143 % CPU, 8.7 GB RSS) + `nix build .#checks.x86_64-linux.test --keep-going` (VM-test builds)** RIGHT NOW, against the #13/#14 reports' written no-heavy-builds gate — the THIRD data point for the enforcement-leg queue row (05:07 burst → 08:2x-3x session battery → 09:0x live). io PSI some avg60 71 %; trips #1841 (08:44:54) and #1842 (08:54:56) already fired in boot 0. **Freeze #16 is loading while this report is written.**
- Owner actions that cannot wait: (1) stop/park the current flake-check + VM-test build session; (2) the physical cooling inspection (standing — direct kill mechanism of three cuts in one night); (3) deploy the landed-but-undeployed `thermal-pstate-guard` + `amd_pstate=active` fix (queue row `[blocked:deploy]`) in the first calm window — noting the paradox that the calm window requires not building.

## a) FULLY DONE

1. Full freeze-#15 autopsy with all discriminators answered (table above); verdict prose delivered to the user with the live warning first.
2. Death-minute IO container identified (session-259 = the soak-unblock session's own workload) — a partial answer to freeze-#14's open §d.1 question and a concrete instance of the recurring class (agent verification batteries as storm-completion drivers).
3. Scrub-fix verification: the freeze-#7 remaining half (`Persistent=false` + serialization) is landed (`f21be80a`, 2026-10-01) and empirically proven across four boots including three crashes — zero catch-up fires.
4. Guard counter continuity + kernel-scan + bundle survival verified across the cut.
5. Crash-loop era timeline reconstructed and anchored: journal-cut boots Oct 1 18:27, Oct 1 18:56, Oct 2 10:57, Oct 3 14:14 (#12), Oct 4 03:36 (#13), 05:07 (#14), 08:38 (#15) — every boot from #1434-era (Sep 29 21:36) onward entered Zone-6 storms within minutes of starting; the storm era is CHRONIC, not incident.

## b) NOTICED, NOT DIAGNOSED (out of scope or tracked elsewhere)

1. gitea-runner crash-loop caused the 03:46 raw-switch status-4 — already tracked (TODO_LIST:227); the bypass-of-deploy-gates aspect is noted in §e.
2. tq-agent-pool's 155/255 GB bursts — standing `[decision]` row (stability.md:guard-coverage); no action taken this session by design.
3. The `Failed to adjust io pressure threshold, ignoring: Device or resource busy` lines during the 03:46 switch — systemd io-pressure knob contention during activation, noticed only.
4. niri `Error::DeviceMissing` flood was boot -3-only (its death minute) — standing desktop row owns it; not reproducing since.
5. The soak-unblock report file (`08-32`) is staged in the index but DELETED from the worktree, not moved to archived/ — another session's action, flagged per the shared-tree rule; this autopsy cites its content from the staged copy (`git show :docs/status/…`).

## c) DELIBERATELY NOT DONE

1. No ClickHouse thermal series for boot -1 — same mid-storm cost argument as #14 §c.2; the live probes (99.1 °C @ 03:46 → 81.5 °C idle-ish @ 05:14 → 76 °C @ load-23 now) already carry the deficit.
2. No guard/module edits — everything candidate is either deploy-gated or a standing `[decision]`/`[blocked:deploy]` row; mid-storm module surgery would also need a build+deploy to matter.
3. crash-autopsy.sh still unwritten — SEVENTH manual protocol derivation (#6/#8/#11/#12/#13/#14/#15); the queued row stands.
4. No stopping of the live flake-check/VM-build session — sandbox blocks it; owner leg flagged in §f.

## d) SELF-CRITICISM

1. **I formed a wrong first hypothesis before reading the sibling autopsies** — the journal-cut + Zone-6-trips signature pulled me toward "IO livelock, scrub catch-up amplifier" and I was halfway to implementing a churn-list edit before discovering freezes #8–#14 were already autopsied as thermal instant-cuts (and the scrub fix already landed + proven). The queued "freeze-family discriminator fork" row exists precisely to prevent this; verdict-shaping evidence collection must START from the prior autopsy chain.
2. The sensors anchor came late (freeze-12 rule: sensors FIRST) — though it landed before the verdict was finalized.
3. Session-259's ~120 GB in 21 min is identified as container-level attribution; the per-process decomposition inside the scope (nix evals vs pool walks vs soak vs signoz restarts) is inferred from the sudo/journal mix, not measured per-process — stated as inference, not proof.

## e) WHAT WE SHOULD IMPROVE

1. **Enforce the no-heavy-builds gate** — the queue row (enforcement leg) now has three violations including one LIVE at autopsy time. Candidate: pre-commit/push hook or a systemd inhibitor check before `nix (flake check|build)` when guard trips are recent — mirrors deploy.sh's zone6_recent gate.
2. **Deploy-tool monoculture**: the 03:46 raw `nh os switch` bypassed deploy.sh's pressure + zone-6 gates and failed status-4 into the bargin. Either wrapper-enforce `nix run .#deploy` (alias interception is weak; a switch-to-configuration wrapper or documentation-level rule is the honest floor) or move the gates into a unit the switch path always crosses.
3. The autopsies' "predicted while writing" pattern (#14 predicted #15's conditions; #13 predicted #14) shows the monitoring exists but nothing ACTS between prediction and cut — the sev1 tiering already demotes memory/storm alerts by owner decision; the OWNER-leg actions (cooling inspection) are the unexecuted half.
4. Session-scope IO attribution should land in the guard trip line at scope granularity (it already prints user-1000.slice children — session scopes were visible; make top-N explicit so the next death-minute container ID is one grep, not archaeology).

## f) NEXT THINGS (self-harvested at authoring; routed to queue/library per TODO rules)

1. **[owner/live] Stop the current flake-check + VM-test build session** (Tctl 76 °C climbing at load 46 avg5; trips active) — owner hands; not a queue row, it is a NOW action.
2. **[owner/standing] Physical cooling inspection** — direct kill mechanism of #13/#14/#15; standing row (stability.md library).
3. **[blocked:deploy] Deploy thermal-pstate-guard + amd_pstate=active** — standing row; this report adds "deploy under minimal build load (single-system build, no VM tests) to avoid manufacturing the storm it must calm".
4. **[ready, evidence-strengthened] No-heavy-builds gate enforcement leg** — existing queue row gains freeze-#15's death-window container + the live 09:0x violation as data points 2 and 3 (both surfaces updated this session).
5. **[ready] crash-autopsy.sh** — unchanged standing row; this report is its 7th input sample.
6. **[watch] Guard re-arm oscillation once tq-agent-pool gets a guard-coverage decision** — unchanged standing [decision] row; no drift introduced.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

None new — the owner questions standing from #13/#14 (cooling inspection timing; deploy window for the thermal fix; whether the soak/schedule work waits for physical inspection) remain the gating items. One operational note: three agent sessions have now run heavy verification work on this box inside active storm windows (two contributed to death minutes); if agent-side self-restraint keeps failing, the enforcement leg (§e.1) is the only durable fix and deserves priority over new feature work.

**Standing state at report close:** freeze #15 autopsied (thermal family, third overnight cut); guard on-cadence (trips #1841/#1842 in boot 0); scrub catch-up fix verified landed + working; tq guard-coverage still owner-gated; thermal-pstate-guard still undeployed; box at Tctl 76 °C under a live build session — freeze #16 conditions present at authoring.

_Arte in Aeternum_
