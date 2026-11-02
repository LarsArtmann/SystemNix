# QLC IO Storm — Live Attribution to llama-chat Cold-Load + Session Status & Brutal Self-Review

**Date:** 2026-10-31, session ran ~18:14–20:34 CEST
**Tree at write time:** HEAD `d0862d7`, clean
**Scope:** THIS SESSION ONLY (owner directive: report on the current run and what it noticed; no external research)
**Trigger:** owner stopped 8 services (`monitor365-server-watchdog.timer monitor365.service monitor365-server.service nsfw-classifier.service monitor365-agent-watchdog.timer mr-sync-dashboard.service tq-agent-pool.service inboxclean-web.service llama-chat-ensure.service/.timer`) and asked why the box still rides 100% QLC I/O.

---

## Verdict (one line)

The live QLC storm is **`llama-chat.service`** — SIGKILLed at 18:11:17, auto-restarted 10 s later, and cold-loading/re-reading the ~20 GB Qwen3.6-35B GGUF from the QLC (`/data` = `nvme0n1p8`) — 87% of all QLC traffic in the measurement window — while every unit the owner stopped (tq-agent-pool, monitor365, …) was yesterday's engine class and their absence **disarmed the memory-emergency-guard's IO-PAUSE action** (`NO eligible headless tree matched`, trip #5310).

---

## Evidence table (all live-probed this session)

| Signal                                     | Value                                                                                                                                                                                                                    | When (CEST) | Source                        |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- | ----------------------------- |
| IO PSI `some`                              | avg10 57.6 / avg60 60.2 / avg300 64.4                                                                                                                                                                                    | ~18:2x      | `/proc/pressure/io`           |
| Memory PSI                                 | avg10 1.06 / avg60 1.98 (clean)                                                                                                                                                                                          | ~18:2x      | `/proc/pressure/memory`       |
| Device map (this boot)                     | **QLC Lexar NQ790 = nvme0n1**, Samsung 970 EVO Plus = nvme1n1; `/` = nvme0n1p6, `/data` = nvme0n1p8                                                                                                                      | ~18:2x      | `findmnt` + `/dev/disk/by-id` |
| nvme0n1 (QLC)                              | **101.5% busy**, 49.1 MB/s read, 2.3 MB/s write (25 s window)                                                                                                                                                            | ~18:26      | `/proc/diskstats` delta       |
| nvme1n1 (Samsung)                          | 1.2% busy, 1.7/2.2 MB/s — hot tier absorbing as designed                                                                                                                                                                 | ~18:26      | same                          |
| Top writer cgroup                          | **`llama-chat.service` 42.9 MB/s of the 49.1 MB/s = 87%**                                                                                                                                                                | ~18:26      | cgroup `io.stat` 25 s delta   |
| Victim cgroups                             | 3 ghostty user scopes at 79–87% `io.pressure`; llama-chat itself only 21% (it's the reader, not the staller)                                                                                                             | ~18:26      | per-cgroup `io.pressure`      |
| llama-chat cmdline                         | `llama-server -m /data/ai/models/jan/llamacpp/models/qwen3.6-35b-a3b-aggressive/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf --port 8850 --ctx-size 32768`                                                 | ~18:28      | `/proc/2872163/cmdline`       |
| Kill event                                 | **18:11:17 `Main process exited, code=killed, status=9/KILL` → `Failed with result 'signal'`**                                                                                                                           | journal     | `journalctl -u llama-chat`    |
| Lifetime stats (killed instance, 1 d 14 h) | 304.1 GB read, 273.9 GB written, 32.9 G mem peak, 19.3 G swap peak, 4 d 18 h CPU                                                                                                                                         | 18:11:17    | same                          |
| Restart                                    | 18:11:27 `Scheduled restart job, restart counter is at 1` → **18:20:30 `Started`** (exactly ONE cycle tonight — verified full-history pull at 20:33)                                                                     | journal     | same                          |
| Guard state                                | Trip **#5310** (zone 6, IO-PAUSE, 18:16:33): **`NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session-)`** — pressure persists, nothing pausable                 | journal     | `journalctl`                  |
| Thermal                                    | k10temp **96 °C**; `DEEP THROTTLE ENTER` 18:16:49 → `DROP` 18:16:59 (cycling)                                                                                                                                            | journal     | `journalctl`                  |
| Gatus                                      | `Memory Pressure CRITICAL` TRIGGERED 18:11:31 (fired correctly — monitoring win)                                                                                                                                         | journal     | `journalctl`                  |
| SEV1                                       | Continuous `MEMORY EMERGENCY GUARD TRIPPED; UNIT CRASH LOOP` (severity=notify) through the session                                                                                                                       | journal     | `sev1-bridge-check`           |
| Memory ceiling                             | llama-chat `memory.max` = 51,539,607,552 (48 GiB); `memory.current` **35.4 GB @ ~18:29 → 13.3 GB @ 20:33** (page-cache eviction — post-load refault phase inferred); RSS stable ~11.5 GB; cgroup-local memory pressure 0 | both probes | cgroup fs                     |
| zram                                       | SwapFree 4.5 GiB of 62 GiB (**93% full**) @ ~18:29 → 12.6 GiB (**81%**) @ 20:33                                                                                                                                          | both probes | `/proc/meminfo`               |
| Storm at report time                       | PSI some avg10 47.8 / avg60 58.1 / avg300 67.0 — **still stalled ~2 h after the restart**                                                                                                                                | 20:33:53    | `/proc/pressure/io`           |
| Killer exclusion                           | kernel OOM + systemd-oomd lines ABSENT in 18:09–18:12 window                                                                                                                                                             | session     | `journalctl` window grep      |
| Tree                                       | HEAD `d0862d7`, clean, no parallel-session edits observed                                                                                                                                                                | 20:33       | content-pin                   |

---

## Straight answers to the three questions asked

- **What did you forget?** → §d (fucked-up list) + the un-attributed SIGKILL + never reading the owning module (`llama-rag.nix`) before recommending lifecycle surgery on its unit.
- **What could you have done better?** → §d items 1–4; chiefly: measure the sample window you actually got, lead containment advice with the doctrine-compliant action, and re-probe before declaring mechanisms ("will repeat").
- **What could you still improve?** → §e — window-discipline tooling, guard-pattern coupling design, scriptifying the attribution loop.

---

## a) FULLY DONE

1. **Live storm attribution to a named unit.** 25 s cgroup-`io.stat` delta + `/proc/diskstats` delta: QLC 101.5% busy at 49 MB/s, `llama-chat.service` = 87% of it. Evidence: numbers above; method per stability.md "measure, attribute, report, recommend".
2. **Device map re-resolved per doctrine** (enumeration flips): QLC = nvme0n1 this boot (flipped again vs 2026-10-22's mapping), Samsung = nvme1n1. No stale-device conclusions.
3. **Restart chain fully reconstructed** — kill 18:11:17 → scheduled 18:11:27 → Started 18:20:30; full-history pull at 20:33 proves exactly ONE cycle tonight (killed the earlier "hidden second restart" hypothesis that a census-timing misread produced).
4. **Killer exclusion (partial → see b1)** — kernel OOM-kill and systemd-oomd lines absent in the 18:09–18:12 journal window.
5. **Guard disarm state documented** — trip #5310's no-match line names the exact mechanism: the owner's stop batch removed every IO-PAUSE pattern target.
6. **Thermal + memory legs census'd** — 96 °C deep-throttle cycling; zram 93%→81%; gatus fired and is counted as a monitoring win.
7. **Routing + pre-read discipline** — read `docs/agents/stability.md` first; grepped `docs/status/` for prior storm reports before diagnosing (found the monitor365 Part-3 quiesce chain and the 10-28 tq attribution, which correctly predicted that stopping tq alone wouldn't end the storm class).
8. **Self-caught measurement artifact** — the "532 MB/s" one-liner was caught as a window mismatch before entering any verdict (details §d1).
9. **Containment path identified and surfaced to the owner** with the correct surface (`llama-chat.service` itself, not the ensure wrapper) — awaiting authorization (§g Q2).
10. **Content-pin discipline** — HEAD + clean-tree verified immediately before writing this report.

## b) PARTIALLY DONE

1. **SIGKILL source attribution** — kernel-OOM and oomd excluded (evidence above); memory-emergency-guard journal 18:05–18:13 NOT yet pulled; operator-terminal hypothesis untested and unexcludable from journals (fish writes history only on exit). **Remaining:** one guard-log pull + owner question (§g Q1). Effort: S.
2. **`Restart=always` claim** — behaviorally proven (Scheduled-restart + auto-Started lines), but the unit's config source (`llama-rag.nix`) was never read; `llama-chat-ensure.service` semantics unexamined. **Remaining:** read the module + runbook. Effort: S.
3. **Storm closure** — the 20:33 probe shows the stall persisting (avg60 58%) with llama-chat in the post-load refault phase (memory.current 35.4→13.3 GB), but the post-load read RATE was not re-measured and no settle-probe exists. Effort: S.
4. **SEV1 `UNIT CRASH LOOP` attribution** — the condition is active, but llama-chat's counter is 1 (below any loop threshold); the owning unit is unidentified (candidates: hermes patchelf SIGSYS class from 10-29, paperless units from 10-30). Effort: S.
5. **Effect-census of the owner's 8-unit stop batch** — verified its guard-disarming side effect and that llama-chat itself stayed up, but did not sweep which of the 8 stayed stopped vs re-armed (stc re-arm rule). Effort: S.
6. **Second fresh llama-server PID (2872245, 1.7 GB RSS, same 414 s age)** — role unattributed (wrapper child vs second model in the unit). Effort: S.

## c) NOT STARTED

| Planned                                                                                     | Why not started                                                                             | Priority |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------- |
| Guard IO-PAUSE pattern-gap fix (cold-load units unpauseable; manual stops disarm the guard) | design work; needs owner-visible proposal first                                             | Critical |
| "Guard disarmed" distinct SEV1 condition (N no-match trips ⇒ own condition, not a log line) | same                                                                                        | High     |
| llama-chat disable-or-pin dispatch (standing `ai-stack.md` [decision] row)                  | owner-gated; tonight is a fresh data point for it                                           | High     |
| Hot-model placement (QLC → Samsung hot-tier) analysis + runbook                             | contradicts the ratified 2026-08-31 role assignment — needs explicit owner reversal (§g Q3) | High     |
| `scripts/io-attribution.sh` (scriptify this session's cgroup-delta loop)                    | tooling; not required to close tonight                                                      | Medium   |
| Runbook update (`llama-rag.md`) with tonight's chain                                        | waits on the containment ruling (Q2)                                                        | Medium   |
| Queueing §f items into TODO_LIST/domain libraries                                           | deliberately deferred — see Harvest note                                                    | —        |

## d) TOTALLY FUCKED UP

1. **Shipped a mangled-window measurement to stdout mid-session.** A bash one-liner printed **"read delta: 532 MB/s"** — 13× inflated: sample `a` came from the 18:26–18:27 window, sample `b` from ~18:29–18:30 (~2.5 min of reads) but the divisor was the `sleep 12`, not the real gap. Root cause: assumed window ≠ measured window. Caught in-review (PSI and the 43–49 MB/s diskstats contradicted it) and never quoted in a verdict — but the artifact line exists in the session transcript, which is exactly the "quote-scrutiny" failure class AGENTS.md bans (the 17-45 §d.2 precedent shipped its mangled awk as findings; this one was one review step from doing the same). Severity: process-toxin; no wrong conclusion escaped. Mitigation: §e1/§e2 + §f17.
2. **Prediction stated as mechanism.** I told the owner the "kill→reload cycle will repeat" — evidence at that time was ONE restart (counter 1). The loop is a freeze-#1-class prediction (zram 93% + Restart=always + next kill), not an observed loop; the 20:33 pull confirmed no second cycle. Severity: verdict-quality erosion, same tier as "happened once ≠ can".
3. **First-line containment advice contradicted doctrine.** I led with `sudo systemctl stop llama-chat.service` — but stability.md's freeze-4 rule says "`systemctl stop` is NEVER containment on this host (stc re-arms stopped units — mask/disable or config-disable)". The mask/config-disable step was mentioned second. Severity: would have cost a re-arm cycle on the next deploy if followed literally. Mitigation: §f3 frames the full ladder.
4. **Phantom-anomaly near-miss.** Census PID age (414 s) against a mis-estimated batch time implied a hidden second restart; I almost queued a "reconcile census vs journal" task. The 20:33 full-history pull disproved it — one cycle, timings consistent. Root cause: batch wall-clock assumed, not measured. Severity: none escaped; logged because the next session may not catch it.
5. **Unexplained probe left dangling.** `journalctl -u llama-chat --since today | grep -c Started` returned 0 (exit 1) while the unit demonstrably started at 18:20:30 — never debugged (tz vs `-u` interaction suspected). Superseded by the full-history pull; low severity.

## e) WHAT WE SHOULD IMPROVE

1. **Window discipline as tooling, not habit.** Every delta pipeline must timestamp both samples and divide by the measured gap. Impact: kills the §d1 class (13× figures) permanently. Fix: the attribution script (§f16) prints `[t0 t1 measured-window]` on every output line.
2. **Post-load phase detection before mechanism claims.** Memory-current drop (35.4→13.3 GB) + stable RSS = refault phase, distinguishable from cold-load — encode that discrimination into the attribution script output. Impact: prevents "still loading" vs "refaulting" misreadings under pressure.
3. **Guard-pattern coupling.** IO-PAUSE patterns are statically coupled to unit availability; any manual stop silently disarms the action (trip #5310 class). Fix: §f5/§f6 — cgroup-read attribution + a distinct "disarmed" condition.
4. **Read the owning module before unit surgery.** I recommended lifecycle actions on `llama-chat.service` without opening `llama-rag.nix` or the runbook. Impact: recommendation quality (ensure-vs-service semantics unknown). Fix: standing pre-read for any `systemctl`-adjacent advice.
5. **Doctrine-first containment phrasing.** Containment recommendations should lead with the freeze-4 ladder (mask/config-disable + deploy caveat), never bare `stop`. Impact: avoids re-arm cycles. Fix: §f3 wording.
6. **Re-probe before "will repeat" claims.** Predictions must be labeled predictions; observed loop counts labeled counts. Impact: verdict trust. Fix: language rule, cheap.

## f) Up to 50 things to get done next (session-grounded; Impact / Effort / Category)

> **HARVEST NOTE — deliberately NOT harvested:** owner directive for this run was "report on this session, then WAIT FOR INSTRUCTIONS"; bulk-queueing 40 items now would duplicate the live dispatch queues and bypass owner triage (precedent: `2026-10-27_22-56_qlc-root-disk-fill-adhoc-diagnosis-status-and-self-review.md` §f note). This section is the HARVEST input when authorized. All items below cite tonight's evidence only.

1. **Contain `llama-chat.service`** (stop + mask now; config-disable as the durable fix) — pending §g Q2. — Critical / S / Bug
2. **Attribute the 18:11:17 SIGKILL**: pull memory-emergency-guard journal 18:05–18:13, trip numbers near 18:11, systemd-oomd unit log; ask §g Q1. — High / S / Bug
3. **Containment ladder wording fixed** for the runbook: stop → mask → `llama-rag.enable = false` (freeze-4 compliant), deploy caveat explicit. — High / S / Documentation
4. **Identify the SEV1 `UNIT CRASH LOOP` owning unit** (query `system_any_service_crash_loop` labels; candidates: hermes patchelf SIGSYS, paperless extraction units). — High / S / Bug
5. **Close the guard IO-PAUSE pattern gap**: add cold-load-capable units (llama-chat at minimum) to the attribution patterns, or switch to cgroup-read-based attribution so pattern-availability can't disarm the action. — Critical / M / Feature
6. **"Guard disarmed" alarm**: N consecutive `NO eligible headless tree matched` trips ⇒ distinct SEV1 condition + DMS notify, not a log line. — High / M / Feature
7. **Re-arm sweep**: verify which of the owner's 8 stopped units stayed stopped (stc re-arm rule) and record the state. — High / S / Quality
8. **Read `llama-rag.nix` + `docs/services/llama-rag.md`**: what `llama-chat-ensure.service/.timer` actually do; whether stopping the timer leaves other triggers armed. — High / S / Documentation
9. **Restart-policy hardening for llama-chat**: `Restart=always` + ~10 s RestartSec re-fires a 20 GB QLC cold-load instantly under storm — evaluate restart throttling or a storm-gate `Condition*` (freeze-33 nsfw-classifier ×7-restart amplifier class). — High / M / Feature
10. **Document the restart-during-storm amplifier class ONCE** in stability.md (nsfw-classifier freeze-33 + tonight's llama-chat restart 10 s post-kill are the same shape). — Medium / S / Documentation
11. **Right-size llama-chat `MemoryMax`** (48 GiB ceiling vs 32.9 G observed peak, zram 93% at trip time). — Medium / S / Quality
12. **Evaluate `--mlock` / `--no-mmap` for the chat model** — refault-read elimination vs the freeze-#1 unevictable-shmem class; analysis only, no blind adoption. — Medium / M / Quality
13. **Placement ruling for hot GGUF models** (§g Q3): QLC doctrine vs Samsung hot-tier move for the chat model — explicit reversal record if it moves. — High / S decision, L work / Decision
14. **Quantify the placement inputs**: tonight's 87%-of-QLC burst + the 304 GB/38 h (≈2.2 MB/s avg) lifetime baseline + 9-min kill→Started gap + storm-amplified reload time. — Medium / S / Documentation
15. **Post-containment verification probe** (PSI, swap, llama state after the stop) — blocked on Q2. — High / S / verify
16. **`scripts/io-attribution.sh`**: scriptify the cgroup-delta + diskstats loop; prints its own measured window + resolves the device map via by-id (never nvmeNn literals). — Medium / M / Feature
17. **Measured-window rule in every delta pipeline** (fix-at-tooling-root for §d1). — Medium / S / Quality
18. **Post-load phase flag** in the attribution output (memory.current drop + stable RSS ⇒ refault, §e2). — Medium / S / Feature
19. **Cold-load progress telemetry**: llama-server load % → textfile metric + gatus "cold-load in progress" state instead of raw-IO-only. — Medium / M / Feature
20. **Verify flm-real/fastflowlm is fully down** (absent from tonight's ps census; check socket + the guard's socket-stop state; ties to the 10-29 disable-or-pin row deploy status). — High / S / verify
21. **Close the 10-29 storm-engine chain**: was the flm crash-loop disable deployed, and is the hermes patchelf SIGSYS ~10-min cadence still firing? — High / S / verify
22. **Crash-loop candidate sweep** (paperless/extraction units from the 10-30 reports — restart counters). — Medium / S / verify
23. **Tonight's storm onset curve**: pull guard trips ~#5290–#5310 timestamps for start time + cadence. — Medium / S / Documentation
24. **Pair the kill with a trip**: was 18:11:17 coincident with a guard trip/action number? (pairs with item 2). — Medium / S / verify
25. **Runbook update** (`llama-rag.md`): tonight's kill/restart/storm chain + containment decision, after Q2. — Medium / S / Documentation
26. **zram-holder census** (top cgroups by swap.current) as a pre-containment headroom tool — 93% full constrained the night's options. — Medium / M / Feature
27. **Check kernel-log directly** (`journalctl -k`) for the 18:11 window to fully close the OOM exclusion (console-level lines vs journal default view). — Medium / S / verify
28. **Diagnose the `--since today` zero-`Started` anomaly** (§d5) — reproduce, identify (tz? unit-match?), or write it off explicitly. — Low / S / Bug
29. **Record the monitoring win**: gatus Memory-Pressure CRITICAL fired at 18:11:31 with correct storm-timeout wording — the detector layer worked end-to-end tonight. — Low / S / Documentation
30. **Confirm ghostty victim scopes recovered** post-storm (3 scopes at 79–87% io.pressure at 18:26; ties to the already-queued upstream ghostty io_uring row — no new row). — Low / S / verify
31. **ClickHouse residual writes** (0.3/1.0 MB/s in the window) — confirm benign post-quiesce. — Low / S / verify
32. **Hot-tier positive evidence** into storage.md context: Samsung at 1.2% busy while the QLC died — the hot-tier doctrine absorbing as designed under storm. — Low / S / Documentation
33. **Record tonight's enumeration flip** (QLC = nvme0n1) as more evidence for the by-id-only discipline in the smartd-trap context. — Low / S / Documentation
34. **Partition-mapping doc check**: `/`=p6, `/data`=p8 tonight — confirm storage docs match the current in-core layout. — Low / S / Documentation
35. **Time-to-availability tax** for the placement decision: 18:11:17 kill → 18:20:30 Started (9.2 min incl. RestartSec + start-under-load) → usable only after the storm-speed load — quantify in the §f14 inputs. — Low / S / Documentation
36. **If placement moves (§f13)**: PSI-gated migrate runbook for the GGUF (caddy-logs/journal hot-tier precedent, `mountpoint=null` disko pattern). — Medium / L / Feature (ROADMAP fuel)
37. **Post-deploy §17 memory-sweep coverage review**: does it see restart-cold-loads (llama-chat class) or only steady-state cgroups? — Medium / S / Quality
38. **Zone-threshold vs single-saturation-device review** — already asked by the 2026-10-28 task report ("is chronic zone-6 the new normal on a post-Samsung-roles box?"); link tonight's episode as one more data point, don't duplicate the row. — Medium / S / Decision
39. **Ensure-timer interplay check**: does the next deploy re-enable `llama-chat-ensure.timer` the owner stopped tonight (Persistent= class behavior)? — Medium / S / verify
40. **Standing ai-stack [decision] row (disable-or-pin) to closure** with tonight as its freshest data point — owner ruling required either way. — High / S / Decision

## g) Three questions I cannot figure out myself

1. **Did you (or anything on your side) kill llama-chat at 18:11:17?** I excluded kernel-OOM and systemd-oomd from the 18:09–18:12 journal window; the guard-log pull is still pending — but your interactive terminals are outside journal reach for live shells (fish writes history only on exit), so if a kill/stop command of yours explains it, that closes item §f2 instantly and I skip the forensic pull.
2. **Is qwen chat supposed to be UP tonight?** If you're actively using `llama-chat`, I leave it running through the storm; if not, I need your authorization for containment (stop + mask now, config-disable as the durable fix) — this is exactly the standing disable-or-pin [decision] row, and tonight is its freshest data point.
3. **Does the 2026-08-31 model-placement doctrine stand?** It keeps AI models on the QLC (bandwidth-bound argument). Tonight: the chat model produced 87% of QLC traffic, a ≈2.2 MB/s lifetime refault baseline, and multi-minute storm-amplified reloads — on the drive that is now the only saturation point. Ratify a reversal for the hot chat GGUF onto the Samsung hot tier, or does the doctrine stand and we fix it in place (mlock/no-mmap/restart-gating only)?

---

## Cross-references

- Doctrine applied: `docs/agents/stability.md` (measure/attribute/report/recommend; freeze-4 stop-is-not-containment; family-C storm+thermal shape — tonight's episode matches the chronic-storm family WITHOUT a new cut: the box survived).
- Prior chain: `2026-10-26_23-43_monitor365-io-storm-root-cause-quiesce-status.md` (monitor365 quiesce), `2026-10-28_18-50_projects-subvol-cutover-deploy-fix.md` (tq 897G/796G engine + quiesce ending trips), `2026-10-29_22-35_crush-0990-plan-executed-deploy1-landed-deploy2-storm-gated.md` (flm-real crash-loop + hermes SIGSYS + ClickHouse churn engines).
- Fresh evidence for: `docs/todo/ai-stack.md` disable-or-pin row; guard IO-PAUSE pattern design (stability library, when harvest is authorized).
