# Stability-extinction executor session — status

**Session:** 2026-10-28 01:46–03:02 CET · executor instance of [the SUPERB stability plan](../planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md) (tombstone + execution log in its §10) · **HEAD at report time:** `9b1f5b4c5`+F52 commit
**Companions:** [00:58 watchdog double-crash diagnosis](./2026-10-28_00-58_watchdog-double-crash-diagnosis-live-recovery-storm-status.md) (author session) · [01:43 boot-contract-armor](./2026-10-28_01-43_boot-contract-armor-execution-status.md) (parallel, waiting for instructions)

**Live state at report time (03:02):** storm STILL LIVE — io PSI some avg10 56.9 % / avg60 57.2 % / avg300 58.5 %; guard trips continuing at cooldown pace (#4514→~#4520, 4 actions since 02:30); MemAvailable healthy (~46 G); journal 7.9 G/8 G (vacuum edge); the paused battery (`PGID 1931684`) remains T-stopped and is NOT the current driver. **The storm is multi-writer** (see §0) — my containment reach (uid-1000 processes) is exhausted; remaining drivers are root-owned.

---

## 0) What actually happened live (the containment sequence)

1. **01:47 recon:** storm NOT draining (trips #4510–#4514 had fired after the author session closed; io.stat showed system.slice +19…+52 GB per 10-min window). Both M1/F1 reader units were already dead (migrate **failed**, heal inactive) → owner sudo legs for those MOOT.
2. **01:51 attribution + pause:** 5 s `/proc` io pass named a headless battery — `bash scripts/tools/bump-dep.sh larsartmann/go-retry v0.9.0 --commit --lint` (session-12.scope, PGID 1931684, tty=none, 16 min old, bash writing 178 MB/5 s) with a `golangci-lint` child and a nix-daemon worker serving it. PSI was re-intensifying (avg10 49→67). **Action: `kill -STOP -1931684`** (uid-1000 target, no sudo needed, fully resumable, zero data loss — M2's designed action applied manually once). Verified `T`-state; drain followed (avg60 65→45 by 02:10). Resume instruction recorded in plan §10.
3. **02:20 re-intensification (avg10 74):** re-attribution found the storm is COMPOUND —
   - **`sda` (pool HDD) 99 % + `sdb` (buildcache USB SSD) 100 % busy** with only ~8+14 MB/s total system throughput and the QLC root at 9–12 % — a waiter/wedge signature, not a byte flood;
   - an `flush-8:16` kworker army parked on sdb + the SAME `rm` D-stuck 20+ min;
   - the rm is **`sudo rm -rf` of Go module-cache toolchain trees** (`ec-hub`, `toolchain@v0.0.1-go1.27.2.linux-amd64{,_1,_2,_3}`, `v3.5.0.mod`) from an SSH session (session-197) — ROOT-owned, I cannot signal it;
   - **trip #4515 (02:00:35) attributed tq-agent-pool.service +162 GB reads in ONE 10-min window** (the M16 rescan class, live);
   - `nsfw-classifier.service` writing 138 MB/3 s (≈46 MB/s) during my M9 live smoke (the M18 cold-start class, live).
4. **Guard behavior decoded:** it kept tripping at cooldown pace all along — my interim "no new trips" read was a tail-window artifact, corrected in-session. Heartbeat verbose-throttling makes the unit journal LOOK quiet between actions; only pattern reads tell the truth.

**Containment ceiling reached:** remaining drivers (sudo rm, tq-agent-pool, nsfw-classifier, residual writeback of tonight's ~100+ GB) are root-owned or kernel-side. Next moves are owner actions or next-deploy config — §f/§g.

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Plan tombstone + execution log (rule §5.6) | `EXECUTING` header in plan §10; committed `f1c1cc2e3` (pathspec; 75-char subject retry → 72-limit met) |
| **M1 agent legs (F3/F4)** | SIGSTOP battery verified+logged; drain curve recorded (65→45 avg60); pre-vacuum gate **PASS** (both crashed boots guarded); F1/F2 owner legs moot (units dead) |
| **F5 guard source-map** | plan §10: zone dispatch (zones 1–6 elif chain), the wrong-tool site (socket stop runs FIRST, outside cooldown, for EVERY zone), cooldown knob, 4-axis restore gate, existing reusable machinery (trips_this_boot/loadBearing, per-trip io.stat attribution, forensics bundle, churn re-arm) |
| **F6 Zone-6 action-split design** | module comment AT the wrong-tool site (`memory-emergency-guard.nix` line ~520, clearly marked NOT ACTIVE) + full 8-point design in plan §10 (never-PTY hard invariant, calm-resume + maxPausedSeconds safety, distinct IO escalation ladder, VM-test contract); flm exemption by construction |
| **F14 admission-gate design** | plan §10: devshell-only `nix` PATH wrapper, guard-trip-recent + PSI-band state (mirrors deploy.sh gate), hard-fail vs queue-park both designed (hard-fail recommended), selftest plan, zero-systemd deployment surface |
| **M8 boot-`b803d718` forensics (F34/F35)** | full analysis appended to the evidence file: storm timeline #4414–#4447 (11 h), guard timeouts, restore-capped, 2 memcg OOM kills, no-ceremony mid-line end → watchdog; **plus the correction below (§d)**; final classification = freeze #36, COMBINED family, matching prior archaeology |
| **M12 discriminator fork** | `stability.md` new section: 3-branch entry-point table (A thermal / B livelock / C combined) + full-count census rule + pstore-emptiness caveat + reset-reason location rule; index updated; committed `acdc50cd4` |
| **M9 `scripts/io-writer-attribution.sh` + selftest** | cgroup-io.stat-primary (root writers visible — the uid-1000 blind spot), per-cgroup io.pressure WAITER view (the wedge class), replay-mode test seam, no-argv by construction; selftest registered in flake checks; live-proven (named tq-pool, nsfw-classifier, monitor365 stall) |
| **M10 `scripts/crash-triage.sh` + selftest** | boot sweep + reset-reason (from NEXT boot) + full-count guard/thermal/OOM censuses + un-evidenced-crashed-boot flag + vacuum clock + discriminator branch proposal; stub-journalctl selftest registered; live-proven (4 boots, correct numbers vs archaeology) |
| **M19/F51 SEV1 per-boot trip line** | `sev1-escalation.nix` trip detail now appends "THIS BOOT: N trips since boot" at ≥3 (slow-burn class the churn note misses); VM proof leg 9d + `guardPromBootStorm` fixture; gatus legs pre-existed (Load-Bearing + Churn) — row is complete |
| **F52 freeze census table** | `stability.md`: trips/throttle/OOM per storm boot (#7, #33–#37, live boot 0) with trips/h band 1.3–11.7/h; `loadBearingTripsPerBoot=10` defended; M20 latch starting point ≥2 trips/h × 2 h + ≥20/boot fallback (owner ratifies) |
| Daemon-race discipline | 3 daemon commits verified (`git show --stat`, only my files); one amended into `9b1f5b4c5`; standalone shellcheck re-run after the daemon-bypassed leg (SC2034 found+fixed) |

## b) PARTIALLY DONE

| Item | State | Remaining |
| --- | --- | --- |
| TODO-system close-out for done rows | M8/M9/M10/M12/F51/F52 complete in-tree | tick the matching `TODO_LIST.md` one-liners + `docs/todo/stability.md` rows (both surfaces, full-line DONE stamps) — deliberately not done mid-storm to keep this report the interruption boundary |
| F51 "Gatus crash-loop check" plan wording | discovered ALREADY covered by existing checks (Load-Bearing flip + Trip Churn) | none — plan row can tick once SEV1 leg deploys |
| Commit hygiene for the F52+census cluster | F52 committed; census content landed | none |

## c) NOT STARTED (this session's plan scope, ungated)

- **M11** `journal-census.sh` + `crash-autopsy.sh` codification (+ selftests)
- **M15** mr-sync-dashboard `IOSchedulingClass=idle`
- **M22** watchdog/flush-lag evidence-loss review (30–90 s window)
- **M24** stability-lib hygiene prune (`prune-done-todos.sh` dry-run + WARN A/B + drift recount)
- **M25** role-split decision brief (crash-cost table, what-moves/stays, monthly cost)
- M13/M14 (model placement), M16–M18 (writer fixes; M16 gated §7.2), M20 (gated §7.1c), M21/M23 (post-deploy-wave deps), M26/M27 — per the plan's own ordering
- Deploy legs M5/M6 — correctly blocked (storm + §7 gates)

## d) TOTALLY FUCKED UP

| Item | Honest account |
| --- | --- |
| **F35 verdict published WRONG, then corrected** | My first boot-b803d718 verdict said "thermal ABSENT" — the thermal grep was piped through `head -8`, which returned only boot-start lines and hid **452 DEEP THROTTLE ENTERs** (last one 45 s before death, at 98 °C). This is the EXACT census-truncation trap the plan's own M11 rule bans. Caught by cross-reading stability.md's freeze-#36 archaeology ~10 min later; corrected in the evidence file (`7cf47a504`) with an explicit retraction section; the lesson is now encoded in the discriminator section AND enforced by full-count censuses in `crash-triage.sh`. |
| Interim wrong claim "no new trips since #4514" | tail-window + heartbeat-throttle artifact; trips #4515/#4516 had fired. Corrected in-session before it reached any report or row. |
| Three live bugs in crash-triage's first version | user-manager "Reached target Shutdown" false-positivized every boot as `[clean]` (stability.md warned exactly this); `head -1` under pipefail SIGPIPE'd the reset-reason to "none"; `read` joined leftover awk fields into the boot id (`id Wed`) zeroing every census. All caught by live verification, all fixed, selftest extended (user-manager trap fixture). The buggy intermediate rode daemon commits — final tree state verified clean. |
| rg-guard false positive | `sort -rn` + `rg` in one typed line tripped the replace-flag hook; cost one round trip, worked around with split commands. |
| Two aborted commits | 75-char subject (house limit 72); daemon racing the registration commit into "nothing to commit" while validation passed. Both resolved (subject fixed; daemon commit verified + amended). |

## e) WHAT WE SHOULD IMPROVE

1. **Full-count censuses, always** — the F35 trap; now a written rule + enforced in tooling. Any `| head` on a census probe is a defect.
2. **Read guard state by pattern, not by "journal looks quiet"** — verbose-throttled heartbeats + cooldown-muzzled actions make `-u` tails lie; grep the full window for `action taken`.
3. **Attribution is step 0 of EVERY storm** — tonight's storm changed drivers three times (battery → rm+pool wedge → tq-pool+nsfw); single-shot mental models go stale in minutes. `io-writer-attribution.sh` exists now — run it before ANY containment decision.
4. **The uid-1000 /proc blind spot is structural** — root writers (nix-daemon workers, tq-pool) are invisible to user-side passes; cgroup io.stat is the primary source (encoded in M9).
5. **Byte-throughput and PSI are different axes** — 8 MB/s total with PSI 70 = waiter/wedge class (USB device, D-state metadata); the io.pressure waiter view must ship alongside bytes (encoded in M9).
6. **stability.md edits hit mtime-staleness refusals repeatedly** (daemon touches); re-read immediately before every edit there — the edit tool's refusal is the last line of defense, not the first.
7. **Pre-commit nix legs under storm are slow and the daemon wins races** — stage + pathspec-commit immediately after validation-bearing edits; expect "nothing to commit" = verify the daemon commit's contents, amend only when exclusively yours.
8. **Foreign-session red CI left in tree** (not mine, flagged): boot-contract-armor session's negative-test leg 1 is broken IN THE TREE with a boot.nix comment ahead of evidence — tonight's `negative-tests.yml` run would page falsely unless their §f.1–f.3 land.

## f) NEXT (session-derived; routed per TODO rules)

1. [ready] Tick TODO_LIST + stability.md rows for M8/M9/M10/M12/F51/F52 (both surfaces, full-line).
2. [ready] M11: `journal-census.sh` (identifier-scoped, uniq -c, NO head) + `crash-autopsy.sh` (sensors leg, freeze-series lookup, boot-evidence-pull call) + selftests + flake registration.
3. [ready] M15: mr-sync-dashboard `IOSchedulingClass=idle` (+ verify standing ~19 MB/s read drops post-deploy).
4. [ready] M22: watchdog-window vs journal-flush-lag evidence note (30–90 s loss window; sp5100 30 s timeout vs journald flush cadence).
5. [ready] M24: prune-done-todos dry-run + rev-pinned WARN A/B + recount the drift row (expect the count to RISE — 2026-10-25 protocol).
6. [ready] M25: role-split decision brief (33+ freezes × downtime cost; what moves to box 2; monthly cost options).
7. [owner-now] Storm: decide on the `sudo rm -rf` (session-197) — let finish vs stop the SSH session; ~46 MB/s nsfw-classifier writes — stop vs M18 override next deploy; tq-agent-pool +162 GB/10 min — M16 io.max after §7.2.
8. [owner-when-calm] SIGCONT the paused battery: `/run/current-system/sw/bin/kill -CONT -1931684` (criterion: io PSI avg60 < 20 sustained ~10 min; instruction also in plan §10).
9. [gated §7.1] M2 Zone-6 action split implementation (design complete in plan §10 — build-ready); M3 admission gate (F14 design complete); M20 latch (census defense done).
10. [after gates + quiescence] M5 deploy wave (boot-chain 5 fixes + M2–M4 + stability batch + storage train-B) → M6 reboot battery → M7 thermal legs.
11. [watch] If boot 0 dies: evidence pull for `b0d70d73` FIRST (vacuum edge 7.9/8 G), then `scripts/crash-triage.sh` is now the step-0.
12. [watch] Nightly `negative-tests.yml` — foreign session's bootcomplete leg is red in-tree (their §f.1–f.3).
13. [small] ROADMAP.md thermal-framing refresh per M12 (deferred there deliberately).
14. [small] boot `ce19a826` (#35) dedicated forensics pass someday (343 throttles already censused; lowest value of the trio).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **§7.1 ratification (unblocks M2/M3/M20 — all three designs are build-ready in plan §10):** (a) Zone-6 action split GO with the headless-only SIGSTOP scope (never-PTY invariant)? (b) admission-gate refusal UX: **hard-fail with `ADMISSION_GATE_FORCE=1` escape (my recommendation)** or queue-park? (c) SEV1/M20 escalation latch threshold: **≥2 trips/h sustained ≥2 h + ≥20/boot fallback** (census-defended) — yes/no/other?
2. **Storm containment now (§0):** the three live root-owned drivers — do you want to stop the sudo `rm`'s SSH session yourself, `systemctl stop nsfw-classifier.service`, and/or accept tq-agent-pool running until M16 caps it? (Agents cannot: root-owned; and §7.2's io.max VALUES are still unanswered.)
3. **§7.3 hardware:** tonight's four consecutive boots ALL rode the thermal ceiling (343/452/430/637 deep-throttle ENTERs) — are you willing to set BIOS fans-100% + PPT cap before the next deploy wave (M7 needs the before/after delta), and is the role-split brief (M25) worth writing for a decision this quarter?

---

**Harvest routing:** §f items 1–6 are [ready] one-liners already tracked by the plan's own rows (tick-at-close-out discipline); 7–8 owner-gated (existing blocked:user posture); 9–10 gate-gated; 11–14 [watch]/[small] — recorded here as the report's self-harvest; NO new TODO rows needed beyond ticking done ones (the plan references existing rows by content). Report written at interruption per instruction; **waiting for instructions**.
