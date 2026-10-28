# Watchdog Double-Crash Diagnosis + Live Recovery Storm — Session Status

**Date:** 2026-10-28 00:58 CET (session ~00:43–00:58, boot 0 = `b0d70d73`)
**Scope:** ad-hoc "why did we crash" diagnosis → fix-plan proposal → this self-review. Diagnosis-only session; **no config changed, no deploy, no unit touched**.
**Live state at report time:** io PSI some avg60 **61.2%** (00:55, was 41% at 00:52 — climbing), memory PSI 0%. Guard already tripped **#4508 (00:49) + #4509 (00:55)** on boot 0 — **the 8th documented post-crash re-fire** (crash-loop amplifier class, freeze-6/22/25/28 lineage).

## The incident (established this session)

- **Two hardware-watchdog deaths in one day**, both confirmed from kernel reset-reason lines:
  - **Boot -2 `b803d718`** (Oct 26 22:55 → Oct 27 10:03) — died by watchdog (`Previous system reset reason [0x02000800]: hardware watchdog timer expired`, logged at boot -1 start 10:04:43). **Death window NOT yet diagnosed.**
  - **Boot -1 `3caf5548`** (Oct 27 10:04 → Oct 28 00:40:38) — died by watchdog (same kernel line at boot 0 start 00:42:49). **Fully diagnosed:**
    - Zone-6 IO livelock, freeze-#3 class: trips every ~10 min from **20:09 (#4482) to 00:35 (#4507)** — 25 trips; final heartbeat: `I/O PSI some avg60=72.42%, disk busy 100.0%, MemAvailable=19.5%`.
    - Writers per guard io.stat: `nix-daemon` (+14.9G window), `tq-agent-pool.service` (+27G final window), `user-1000.slice` (+35G window) — consistent with the evening's parallel sessions (report titles 00:20–00:22: opencloud deploy8, browser-history-ai-rewire, paperless VM-test iteration) + deploys.
    - **Thermal ceiling stacked**: k10temp **100 °C** at 00:38:45, thermal-pstate-guard DEEP THROTTLE flapping (enter 00:38:45 / drop 00:38:51 — saturated cooling, guard oscillating).
    - Journal cut mid-write 00:40:38 with 30–90s flush lag, no shutdown ceremony, no panic → hang → sp5100-tco watchdog reset (~2 min later). pstore EMPTY, /var/crash EMPTY (no vmcore — consistent with livelock class).
- **Fix plan proposed (owner-gated, not implemented):** (1) Zone-6 action split — IO trips SIGSTOP driver trees `[blocked:user]`; (2) admission gate for the battery class `[ready]`; (3) post-crash reader-pause automation `[ready]`; (4) thermal/cooling + model-set→Samsung (owner legs).

## a) FULLY DONE

1. Boot -1 death root-caused end-to-end: watchdog ← hang ← Zone-6 IO livelock (25 trips, 4.5h) + 100 °C thermal ceiling, with writers named at cgroup level.
2. Discovered the **same-day second watchdog death** (boot -2) — the day's crashes are a PAIR, not one event.
3. Live recovery storm on boot 0 detected and attributed: guard trips #4508/#4509 (counter continuity #4507→#4508); per-PID 6s attribution: **`go` 83 MB/6s (agent build battery), `project-discovery` 32 MB/6s**, system.slice +20G/6min (catch-up writers class).
4. **Evidence pulls for BOTH crashed boots** (`docs/status/tasks/2026-10-27_23-57_boot-3caf5548-evidence-pull.md`, `…_boot-b803d718-evidence-pull.md`); **pre-vacuum evidence gate: PASS** (was going to block the next deploy; journal at 7.9G/8G — the pull raced the vacuum clock).
5. "Once and for all" fix plan delivered with the owner-gated decisions isolated from the [ready] work.

## b) PARTIALLY DONE

1. Recurring-family root cause: complete on existing-doc + tonight's evidence, but **boot -2's death window (Oct 27 10:03) undiagnosed** — evidence pulled, not analyzed.
2. Thermal picture: guard's 100 °C spike documented; SigNoz k10temp hourly-maxima pull for Oct 27 NOT done; fan telemetry claim ("zero fan telemetry") taken from docs, not live-verified.
3. Fix plan: proposed and evidenced; nothing ratified, nothing landed.

## c) NOT STARTED

- Zone-6 action split (row 157), battery-class admission gate (row 135), post-crash reader-pause automation (row 156), model-set→Samsung (row 234), cold-load serialization (row 233), llama pre-warm (row 231).
- Any deploy (correctly — none should fire into a 61% PSI window).
- Boot -2 forensics; boot 0 post-recovery health sweep (failed units, gatus state) — systemctl probe is guard-blocked, busctl workaround not yet used.

## d) TOTALLY FUCKED UP (session misses, honest)

1. **First writer-attribution pass was silently broken**: `rg -o '(?<=…)'` — rg's default engine has no lookbehind; the error was eaten by `2>/dev/null` and the pass printed "no movers" while PSI was 61%. Caught only by the quote-scrutiny sanity rule; redone in awk. Exactly the mangled-pipeline class this repo documents (2026-10-23 rule).
2. **Framed the crash as one event initially** — the second watchdog death surfaced only via a secondary grep. Step 0 of crash triage should be reset-reason for the last N boots, not just the current one.
3. **Missed pstore/vmcore checks until review pass** (both empty — no harm, but the probe order was wrong).
4. **Cited the 00:20–00:22 status reports by title only** — never read them; the evening-session attribution rests on guard io.stat + filenames, not report content.
5. **"33 freezes" stated without tally verification** — stability.md cites freeze-33; the exact count was not confirmed.
6. **No boot-0 failed-unit check** (systemctl guard-blocked; the documented busctl ListUnits pattern was available and unused).

## e) WHAT WE SHOULD IMPROVE

1. Crash-triage step 0 = reset reason for last N boots + evidence pull for EVERY un-evidenced crashed boot + vacuum-clock read — tonight the journal sat at 7.9G/8G while two un-evidenced boots were at vacuum risk. Make it a script.
2. The /proc io attribution pass must be `scripts/io-writer-attribution.sh` (fixture-tested) — the hand-rolled one-liner failed exactly as the quote-scrutiny rule predicts.
3. **Recovery-storm containment is still manual doctrine** — 8 re-fires documented, row 156 exists, and tonight's boot 0 storm ran untouched for 13+ min while I wrote prose instead of pausing readers.
4. **Zone-6's socket-stop action is now proven wrong-tool 4×** (#24, #25, tonight ×2 — trips #4507/#4509 executed into a go/nix-daemon storm and changed nothing). The guard is burning actions that cannot touch the drivers.
5. Guard trip counter persistence across boots is good forensics (#4507→#4509) — keep; add per-boot trip-count to the SEV1 line for at-a-glance crash-loop detection.

## f) NEXT (prioritized; owner = needs your hands/verdict, ready = dispatchable)

**Harvest note:** deliberately NOT harvested into TODO_LIST.md/domain libraries yet — owner ordered report-then-wait; harvest on instruction (items 2–4, 11–15, 17, 19, 21 map to existing stability.md rows; only 9/10/16/20/22 are net-new asks).

1. **[owner, NOW] Contain boot 0's live storm**: stop recovery readers (crush-hot-db-migrate, discordsync-db-heal-class) + park the `go` battery tree; PSI avg60 was 61% and climbing at 00:55.
2. **[owner-gated] Ratify Zone-6 action split (row 157)** — IO trips SIGSTOP driver trees (headless only); Z6 cooldown 120–180s; distinct IO escalation path.
3. **[ready] Battery-class admission gate (row 135)** — refuse `nix build`/`flake check`/VM tests while guard recently tripped / PSI in band (deploy.sh gate shape).
4. **[ready] Post-crash reader-pause automation (row 156)** — tonight is re-fire #8; strongest evidence yet.
5. **[ready] Diagnose boot -2's death window** (Oct 27 10:03) — evidence file already pulled; same class as boot -1?
6. **[ready] SigNoz k10temp hourly maxima for Oct 27** + live-verify fan telemetry absence (sensors).
7. **[owner] Physical cooling inspection** — standing deficit (99 °C at load 20 documented); no gate fixes physics.
8. **[ready] Model set → Samsung hot tier (row 234)** + serialize cold loads (row 233) + llama pre-warm (row 231).
9. **[ready] `scripts/io-writer-attribution.sh` + selftest** (see §e.2).
10. **[ready] Crash-triage script: reset-reason-last-N-boots + un-evidenced-boot sweep + vacuum clock** (see §e.1).
11. **[ready] mr-sync-dashboard IO idle-class / sync window (row 95)** — standing ~19 MB/s reader makes "wait for drain" structurally unavailable.
12. **[ready] tq-agent-pool + build-slice `io.max` cgroup caps (row 88)** — owner throughput tradeoff attached.
13. **[decision] nsfw-classifier storm-aware restart gating (row 17)** — 7 crash-restarts in 90 min class.
14. **[decision] SEV1 sustained-escalation leg, option B (row 249)** — warn-tier banner at ≥3 trips/h × 2h.
15. **[ready] systemd-bless-boot ordering after boot-mirror-sync (row 172)** — counter exposure: fallback generation looms if crashes keep landing.
16. **[ready] Boot-0 post-recovery sweep once PSI drains**: failed units (busctl), gatus end-to-end, boot-mirror verify (rode past crashes unverified before).
17. **[decision] flm Zone-6 exemption (row 40)** — cold loads read /data p8, not QLC root.
18. **[owner, strategic] Role-split verdict** — second box for services/builds vs one-box-with-gates; the only path that makes the class EXTINCT rather than managed.
19. **[ready] Watchdog window review** — sp5100-tco timeout vs the freeze signature (journal flush lag means the last 30–90s of evidence is systematically lost; is a shorter window better?).
20. **[ready] Commit/verify the two evidence files** landed cleanly (auto-daemon may have swept them; `git log --stat` check).
21. **[ready] Guard per-boot trip counter in SEV1 line + Gatus** (§e.5).
22. **[ready] Read the three 00:20–00:22 reports** to confirm/refine the evening-session attribution (§d.4).

## g) Questions I cannot answer myself

1. **Zone-6 action split (row 157):** go/no-go — and if go, confirm the scope stays *headless battery/driver trees only*, never owner PTYs (per the 2026-10-07 SIGSTOP-license revocation)?
2. **Admission-gate refusal shape:** when a storm is live, should `nix build`/`flake check`/VM tests hard-FAIL with a calm-window hint, or queue-park until PSI drains? (You removed the 2026-10-14 PSI nix-shim for blocking work — what form of "no" is acceptable to you?)
3. **Boot 0, right now:** the recovery storm is live (avg60 61%, a `go` battery is writing). I cannot sudo or kill your processes — want a paste-ready containment command list (which readers/trees to stop), and is that `go` build still needed or killable? (Fold the role-split/second-box verdict in here if you want — it's the same tradeoff at larger scale.)

## Verdict

Diagnosis: solid and evidence-locked (both boots). Response: prose-heavy, action-light — the known fixes sat in the queue while the recovery storm re-formed live for the 8th time. The box will keep dying until row 157 + row 135/156 are ratified and landed, or the roles are split.
