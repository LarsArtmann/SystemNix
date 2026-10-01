# FastFlowLM Socket-Down + Sustained QLC IO Storm — Read-Only Diagnosis Session

**Date:** 2026-10-01, 02:30–05:45 CEST (session span)
**Scope:** FastFlowLM availability question → live IO-storm root-cause via /proc + cgroup io.stat deltas.
**Mode:** 100% read-only diagnostics. No config changes, no deploys, no commits, no service starts/stops.
**Operator:** crush session, SystemNix cwd.

---

## 0. One-paragraph verdict

FastFlowLM is intentionally DOWN (socket + backend both stopped); the memory-emergency-guard is holding it down under a **genuine, currently-active sustained IO storm** on the QLC NVMe (io PSI some avg60 43–54%, disk-busy corroborated to 77%). The live storm driver was measured, not guessed: **`nix-daemon.service` moving ~12 MB/s continuously** (~121.5 MB per 10s cgroup delta); every other cgroup is noise (<2.2 MB/10s). Cumulative since boot (41h): the **tq-agent-pool has churned 2.63 TB** and nix-daemon 947 GB. The correct action was and is: do NOT restart flm mid-storm; drain/serialize the build drivers first.

---

## 1. Session timeline

| Time (CEST) | Event |
| --- | --- |
| ~02:30 | User asks: "What is the RAM limit for FastFlowLM?" → answered from AGENTS.md (MemoryMax 40G, OOMScoreAdjust=300, exponential restart backoff 60s→15min). |
| ~02:33 | User asks: "is it running?" → first probe attempt via `systemctl` **BLOCKED by sandbox policy**; fell back to `/proc/net/tcp` (hex `:CD91`/`:CD92`) + `ps`. Result: zero listeners on 52625/52626, zero flm processes → backend idle AND public socket down (clients would ECONNREFUSED). |
| ~02:35 | User pastes `systemctl status fastflowlm.socket fastflowlm.service`. Analysis: socket up 02:10:38 → 02:11:36 (57.7s, then "Deactivated successfully"); backend 02:14:57 start → server bound 02:16:30 → "Stopping" 02:19:39 → clean deactivate 02:19:41. Cold load was HEALTHY (21.7G disk read, 30.8G mem peak, 27.8s CPU). Socket lifetime counters: Accepted 133, Refused 8. |
| ~02:42 | User pastes `journalctl -u memory-emergency-guard -n 20` + "something seems wrong". Guard running every 30s, mostly clean finish; one check-script line: `MEMORY EMERGENCY still active (I/O PSI some avg60=54.35% sustained (max disk busy 77.3%, MemAvaila…` (truncated in paste). |
| 02:45–02:55 | Deep /proc + cgroup investigation (below). Verdict delivered: guard healthy, storm real, driver = nix-daemon builds; recommendation: don't restart flm, thin the agent swarm. |
| 05:38 | Status report authored (this file). |

---

## 2. Verified findings (evidence-backed)

### 2.1 Boot age and context
- `/proc/uptime` = 147,090s ≈ **40h51m** → boot ≈ **2026-09-29 ~09:54 CEST**, i.e. **this is the post-freeze-#7 boot** (freeze #7: 2026-09-29 09:51 hard reset). The box is 41h into that boot with zero reboots since.
- flm's socket events tonight (02:10–02:11) were NOT boot events — they were runtime stop/start by something (unidentified, see §2.5).

### 2.2 The storm is real and current (measured twice)
- PSI io at ~02:47: `some avg10=56.15 avg60=42.92 avg300=48.71`; `full avg10=49.07 avg60=29.25`.
- PSI memory: ~0 everywhere. `MemAvailable` 75.8 GiB. Swap 30.5/62.2 GiB used (~51% — half the zram, unremarkable).
- `/proc/diskstats` delta over 3s: `nvme0n1p6` (**root `@`, QLC**) +14 io_ticks (~47% duty); Samsung `nvme1n1` ~0. The storm is **QLC-root-local**.
- Dirty page cache 55 MB, Writeback 0 → not a writeback storm; it is sustained device-level read+write.

### 2.3 Live driver: nix-daemon (measured, not inferred)
Per-cgroup `io.stat` **deltas over 10s** (~02:55):
- `system.slice/nix-daemon.service`: **121.5 MB** (~12 MB/s) — the storm.
- `system.slice/clickhouse.service`: 2.2 MB. `systemd-journald`: 1.7 MB. Everything else ≤0.1 MB.
→ Active nix builds are the live IO driver on the QLC root disk.

### 2.4 Cumulative IO since boot (41h attribution)
| Cgroup | Bytes (r+w) | Note |
| --- | --- | --- |
| `tq-agent-pool.service` | **2.63 TB** | Dominant churner of the whole boot |
| `nix-daemon.service` | 947.6 GB | Builds |
| `clickhouse.service` | 150.4 GB | Telemetry |
| `systemd-journald` | 20.8 GB | |
| `papdashboard` | 18.9 GB | |
| `project-discovery-daemon` | 18.2 GB | |
| `system-immich.slice` | 15.6 GB | |
| `projects-management-automation` | 12.2 GB | |
| `system-systemd\x2dcoredump.slice` | **11.9 GB** | Core dumps being written this boot — NOT yet investigated |
| `docker.service` | 10.1 GB | |

### 2.5 Live process landscape (at ~02:50)
- `bash scripts/tq-ladder.sh 000001a0… --predicate` — **99.4% CPU, 12.5 min elapsed, cwd `~/projects/CV`**. Zero disk reads in a 5s window (CPU/page-cache bound). Assumed (unproven) to be the nix-daemon build driver.
- `bun /tmp/server-smoke.mjs` — **98.5% CPU for 37 min**, cwd `~/projects/nsfw-classifier`, zero disk reads. **Doctrine violation: operational script under `/tmp`** (tmp-cleanup eats >4h-stale entries; a long-running smoke in /tmp also violates the 2026-09-19 deploy-queue lesson).
- **≥11 headless `crush -y` sessions** (tq-pool agents and/or interactive): cwds seen = go-cqrs-lite, SystemNix, go-datastar, InboxClean. This is the freeze-#6 "concurrent agent sessions" class.
- qemu **nix-email demo VM** — up 9.9h, 2G RAM, hostfwd 18080/2525/2587/2593, drive `~/projects/nix-email/demo.qcow2` cache=writeback. Zero measurable IO in the delta window.
- helium (video playback likely), clickhouse-server, node_exporter, gatus, nsncd — background normal.

### 2.6 FastFlowLM state and the guard
- flm cold load tonight was **textbook-healthy** (21.7G read, 30.8G peak, no device error, no crash, clean deactivation) — no evidence of the v1.0.2 crash class.
- The guard is running every 30s and its ongoing-state line confirms a sustained **Zone-6-shaped** condition (io avg60 ≥40% + disk-busy corroboration 77.3%). Memory zones are NOT firing (MemAvail 76G, mem PSI 0).
- Guard doctrine check: idle-timer did NOT stop the backend at 02:19:39 (idle stop requires backend active ≥10 min; it was active 5m45s). The stopper of both the socket (02:11:36) and the backend (02:19:39) is **not identified** in available evidence — the user's guard-journal paste starts at 02:42 and does not cover 02:10–02:20.

### 2.7 Documentation discrepancy found (potential AGENTS.md correction)
The user's `journalctl -u memory-emergency-guard -n 20` paste DID include a `memory-emergency-guard-check[388155]:` line. AGENTS.md's stability section claims the guard's script output logs under syslog id `memory-emergency-guard-check` and that "`journalctl -u memory-emergency-guard` NEVER shows it". Tonight's evidence contradicts the absolute form of that claim (at least one check line surfaces under `-u`). Needs a one-time verification and an AGENTS.md precision fix (e.g. "usually" vs "never", or the verbose/heartbeat lines specifically are the ones suppressed).

---

## 3. a) FULLY DONE

1. RAM-limit question answered correctly from authoritative context (MemoryMax 40G, OOMScoreAdjust 300, restart backoff).
2. flm liveness determined WITHOUT systemctl: `/proc/net/tcp` hex port check (`:CD91`/`:CD92`) + process scan — correct hex discipline (decimal grep / wrong-hex false-green trap avoided by doctrine).
3. Correctly distinguished "backend idle" (normal) from "public socket down" (abnormal → clients ECONNREFUSED instead of cold-load).
4. Parsed the user's systemctl paste into a precise timeline; identified the healthy cold load (21.7G/30.8G) and clean stops.
5. Identified the socket-down-while-service-loads pattern as the guard sacrifice signature (socket first, in-flight backend swept after).
6. Guard cadence + ongoing-state condition extracted from the paste (30s ticks, io avg60 54.35%, disk busy 77.3%).
7. Live storm root-caused to `nix-daemon.service` with a measured 10s cgroup delta (121.5 MB) — not inferred from CPU%.
8. Avoided misattribution: measured per-process io deltas for the top-CPU suspects (tq-ladder, bun, crush) — all ZERO disk reads; correctly reclassified them as CPU/page-cache bound.
9. Boot age computed and tied to freeze #7 recovery boot (41h, Sep 29 ~09:54).
10. Cumulative-since-boot IO attribution table produced (tq-agent-pool 2.63 TB dominates).
11. Live suspect inventory with cwds (CV, nsfw-classifier, go-cqrs-lite, SystemNix, go-datastar, InboxClean) + the 10h demo VM.
12. Correct operational recommendation: no manual flm start mid-storm (would re-pay 21.6G cold read and re-trip); wait for drain; auto-restore path explained.
13. Flagged the `/tmp` ops-script doctrine violation the moment it was seen.
14. Zero destructive actions; sandbox-blocked command handled with immediate fallback.

## 4. b) PARTIALLY DONE

1. **Guard trip forensics at 02:10–02:20**: hypothesized a guard trip/restore cycle but never pulled the trip-window journal (paste only covered 02:42+). Who started the socket at 02:10:38, who stopped it at 02:11:36, and who stopped the backend at 02:19:39 is UNKNOWN. The idle-timer is excluded for the 02:19:39 stop (active only 5m45s < 10 min) — so a real actor is unaccounted for.
2. **flm recovery state**: auto-restore conditions explained, but the actual restore budget / `restore_capped` state was never read (the guard's textfile `.prom` at `/var/lib/prometheus-node-exporter/textfile_collectors/` is world-readable and was never checked).
3. **tq-ladder → nix-daemon causal link**: presented as "almost certainly" but never proven (no check of nix-daemon child processes / build queue).
4. **Freeze-risk quantification**: named the freeze-#5/6/7 pattern but did not check trip counters for today, storm duration history (avg300 48.7% implies ≥5 min-scaled exposure; the guard line implies longer), or whether the 2026-09-29 scrub-template fixes are the reason no scrub joined the storm.
5. **Last night's backups**: btrbk root/data/pool run at 23:00/23:30/23:45 — BEFORE tonight's storm window (02:11+), likely fine, but never verified (backup-coordination `.prom` readable, unchecked).
6. **Guard churn-window state**: whether btrbk/scrub units are currently guard-stopped and whether a churn re-arm is pending was never checked.
7. **tq-agent-pool 2.63 TB**: reported but not drilled — the cgroup io.stat carries a per-device breakdown (QLC vs Samsung) that would show WHERE the churn landed (crush-hot-db migration effectiveness check was available in the same file and not taken).

## 5. c) NOT STARTED (deliberate or missed)

1. Guard `.prom` metrics read (trips today, zone counters, restores, `restore_capped`, `last_run_timestamp`).
2. Full untruncated guard line via `journalctl --grep "MEMORY EMERGENCY"` / identifier grep (the paste was cut mid-word).
3. Trip-window journal pull (02:08–02:22) for all involved units (guard, socket, backend, @instance).
4. nix-daemon build attribution (children of nix-daemon → which agent/drv is building).
5. tq-agent-pool per-device IO breakdown (QLC vs hot-tier).
6. `/tmp/server-smoke.mjs` investigation: owner, purpose, runaway-or-not (37 min for a "smoke" is suspicious), rescue to `~/.local/state` if legitimate.
7. `systemd-coredump` slice 11.9 GB this boot — what core-dumped, how many, is something crash-looping quietly? (Flm had a healthy night; coredumps predate tonight's events.)
8. Last night's backup-freshness verification.
9. AGENTS.md precision fix for the `journalctl -u` guard-output claim (§2.7).
10. TODO harvesting of this report's follow-ups — **deliberately deferred: the user ordered "report, THEN WAIT FOR INSTRUCTIONS"**; per repo doctrine the non-harvest decision is recorded here explicitly instead of silently skipping it.
11. Any commit — none made (read-only session; report file itself left for the auto-commit daemon / user).

## 6. d) TOTALLY FUCKED UP (honest list)

1. **First probe wasted on a blocked command**: opened the "is it running?" check with raw `systemctl`, which the sandbox security policy rejects. Cost one round trip; the fallback (/proc) should have been the opening move given this environment.
2. **Unverified causal claim delivered with too much confidence**: "tq-ladder.sh … almost certainly the one driving the nix-daemon builds." The nix-daemon IO is fact; the causal attribution was never tested (its zero-read behavior even weakens it — the builds may belong to one of the 11 crush sessions or a `nix build` spawned inside the ladder's subshells). Should have been labeled hypothesis.
3. **Trip-narrative presented before evidence**: the "guard trip at ~02:11:36, backend swept at ~02:19:39" story was constructed from the sacrifice PATTERN (which fits) but no trip-time journal line was ever seen. The 02:19:39 stopper is actually unknown (idle-timer excluded). The final message softened this; the intermediate one didn't.
4. **Missed free evidence**: the guard's own `.prom` textfile (world-readable) and the per-device breakdown inside the already-collected io.stat were one command away and not taken.
5. Nothing destructive occurred; no file was edited besides this report; no git state was touched.

## 7. e) WHAT WE SHOULD IMPROVE

1. **Guard-first diagnostic order**: when the guard is implicated, read its textfile `.prom` FIRST (world-readable, authoritative, has trips/restores/caps) before any journal or paste analysis.
2. **Never analyze truncated evidence silently**: the guard line was cut at "MemAvaila…" — the full line (thresholds, zone, MemAvailable value) belongs in the analysis; fetch before concluding.
3. **Label hypothesis vs measurement in-line**, every time, especially on causal claims ("drives the builds") — this session's final answer did, the middle one didn't.
4. **/proc-first reflex in this sandbox**: systemctl is policy-blocked; the working toolkit is `/proc/{net/tcp,diskstats,pressure,*}`, `/sys/fs/cgroup/**/io.stat` deltas, `ps -eo`. Document the recipe (cgroup delta join over 10s) as a reusable one-liner — it directly answered "who is storming" in one shot.
5. **Unidentified actor discipline**: when a unit was stopped by *someone* and the evidence window doesn't cover it, say "stopper unknown + which journal window would answer it" instead of fitting a story.
6. **Sweep adjacent anomalies in the same evidence**: the 11.9 GB `systemd-coredump` slice was sitting in the first cgroup table and wasn't chased (out-of-scope per user order, but should have been listed as an observation immediately — it was, in this report, only at authoring time).

---

## 8. f) UP TO 50 THINGS TO DO NEXT (all rooted in this session's observations)

**FastFlowLM recovery (1–8)**
1. Read guard `.prom`: `trips_last_hour`, `zone6_trips_total`, `restored_total`, `restore_capped`, `last_run_timestamp` — establish whether flm is capped or will auto-restore.
2. Pull trip-window journal 02:08–02:22 for `memory-emergency-guard(-check)`, `fastflowlm.socket`, `fastflowlm.service` — identify who started the socket at 02:10:38, who stopped it at 02:11:36, and who stopped the backend at 02:19:39 (idle timer excluded by its own ≥10min rule).
3. Retrieve the FULL guard line (untruncated) — capture MemAvailable value + zone + thresholds present in the message.
4. Identify what nix-daemon is building right now (children of nix-daemon, `ps --ppid`) and map to the owning agent/tq task.
5. Decide tq-ladder.sh disposition: let finish / stop / re-run under `heavy-job` (it is the 99%-CPU CV-repo ladder driving (probably) the builds).
6. After storm drains (io some avg60 <40% sustained): verify flm auto-restores; if capped, bind-test both ports then `sudo systemctl start fastflowlm.socket`.
7. Post-restore verification: `/v1/models` 200 + cold-load wall time + no `bind: Address already in use` (the orphan-pair/corpse class).
8. Confirm PMA commit path health during the flm outage window (PMA falls back to heuristic commits on connection-refused — check fallback counter spike tonight).

**Guard + storm forensics (9–16)**
9. Count today's Zone-6 trips from metrics; compare against freeze-#5 pre-storm signatures (episodic vs sustained).
10. Check whether the guard's churn-stop engaged tonight (are btrbk-root/data/pool + balance + scrub template instances currently stopped?) and whether a re-arm is owed.
11. Verify last night's btrbk runs (23:00/23:30/23:45) completed BEFORE the storm window — backup-coordination `.prom` + pool receive names.
12. Check the sev1 bridge tonight: did "MEMORY EMERGENCY still active" produce the notify-tier alert (30-min cooldown)? If the user learned about the emergency by asking about flm instead of from an alert, that is an alert-visibility gap.
13. Verify whether the storm tripped `backup-starvation catch-up` logic (storm duration vs 6h threshold — it started ~02:11, too short so far, but monitor if it persists past ~08:11).
14. Confirm no scrub is currently running into the storm (weekly scrub window + 2026-09-29 template-instance fixes) — btrfs-health metrics + `btrfs scrub status` as root.
15. Duration-tracking: if avg60 >40% persists >2h, pre-emptively check disk-time attribution per cgroup again (10s delta) to catch a SECOND driver joining (the nix-daemon may finish and hand off to btrbk catch-up, crush migration resume, etc.).
16. Decide whether the deploy pressure gate / deploy plans tonight must wait (rc=12 conditions are met: avg10 ≥20% repeatedly).

**QLC churn — structural (17–24)**
17. Drill tq-agent-pool io.stat per-device: how much of the 2.63 TB hit QLC root vs Samsung hot — measures crush-hot-db migration effectiveness for the POOL's sessions (pool agents may predate the migration or use other churn paths).
18. Verify crush-hot-db symlinks exist for the repos with live agents tonight (CV, go-cqrs-lite, go-datastar, InboxClean, SystemNix, nsfw-classifier) — `ls -la <repo>/.crush`.
19. Compute tq-pool IO per completed task (2.63 TB / tasks-done since boot) — a cost-per-task waterline for the 30/day budget decision.
20. Evaluate whether tq-pool agents' git/grep hot paths can be shifted off QLC root (shared object caches, `~/.local/state` workspaces on hot tier).
21. Check `systemd-coredump` slice (11.9 GB this boot): which units core-dumped, when, how many — quiet crash-loop detection. (Explicitly NOT investigated yet; may relate to flm's historical crashes or something else entirely.)
22. Re-check `system_crush_sessions` metric vs the observed ≥11 sessions — the Gatus threshold is >6; did it page tonight?
23. Consider a max-concurrent-agents admission rule during guard-active windows (freeze-#6 rule (d)) — currently nothing enforces it across interactive + pool sessions.
24. Assess nix-daemon IO tiering: builds at ~12 MB/s continuous are the storm; is `ioTier.build` (BE/7) applied to nix-daemon and is it enough during multi-session build storms?

**Hygiene / doctrine violations seen tonight (25–30)**
25. `/tmp/server-smoke.mjs`: identify owner session; if legitimate, move to `~/.local/state/<project>/` per ops-artifact doctrine; if runaway (37 min), stop it.
26. Verify the tmp-cleanup interaction: the smoke script is <4h old now, but if it runs past 4h staleness the cleaner deletes it mid-run — same trap as the 2026-09-19 deploy-queue incident.
27. AGENTS.md precision fix: `journalctl -u memory-emergency-guard` DID surface a `memory-emergency-guard-check` line tonight — soften/correct the "NEVER shows it" claim after a one-time verification.
28. Add the cgroup-io.stat-delta one-liner to the repo's diagnostic toolkit docs (it root-caused tonight's storm in a single command without root).
29. Add "check the guard .prom before journal" to the flm/guard runbook (`docs/services/memory-emergency-guard.md`).
30. Record tonight's healthy-cold-load datapoint (21.7G read / 30.8G peak / clean exit) in the flm runbook as a v1.0.2-good baseline signature.

**Monitoring gaps exposed (31–36)**
31. The user discovered the emergency by ASKING about flm — audit the notify-tier path for this storm: did DMS notify fire (cooldown 30 min), did Discord fire, was the amber banner shown?
32. Check "Memory Guard Collector Fresh" + guard-death checks were green during the storm (they should be — guard visibly ticking).
33. Gatus "FLM Restore Capped" notify: confirm it would have fired if capped (it is the standing signal that flm stays down past budget).
34. SigNoz: confirm io-PSI dashboards captured the 02:11+ storm (node_psi_io_some_avg60) — panel exists per stability doctrine; verify data landed.
35. Consider an alert or dashboard line for "nix-daemon sustained IO" (build storms are now a recurring driver: tonight, freeze #5, freeze #6).
36. Check Refused-counter source on the socket (8 lifetime refusals — which clients hit ECONNREFUSED windows tonight; PMA enricher retries expected).

**Environment/session notes (37–42)**
37. The nix-email demo VM has been up 9.9h holding 2G RAM — confirm with owner whether to keep overnight (memory is healthy; this is a tidiness/intent question, not urgent).
38. ≥11 concurrent crush sessions: inventory interactive vs tq-pool (tq budget is 30/day, max 3/tick — 11 processes exceeds the tick cap, so most must be interactive/other sessions; verify no budget overrun).
39. Verify nsfw-classifier session state (the bun smoke's cwd) — is that session still active/expected?
40. If the storm persists toward the 04:10 `crush-hot-db-migrate` timer and 02:xx–04:xx maintenance windows, pre-check for stacking (freeze-#6 crash-recovery-reader amplification class).
41. Cross-check `swap` composition: 51% of zram used with mem PSI 0 — fine now, but flm restore would add ~22G anon/shmem pressure; restore decisions should re-read zram fill at that moment (guard already excludes zram from restore gates — doctrine holds, just observe).
42. Confirm `/run/current-system` == profile (no deploys happened tonight, but the 41h-old boot + prior sessions' exit-4 history makes a 10-second anchor check cheap before any future reboot).

**Report/process (43–47)**
43. Harvest §8 items into TODO_LIST.md + domain libraries ONCE the user lifts the "wait" order (this report records the deliberate deferral).
44. Update AGENTS.md only after the `-u` journal claim is re-verified (avoid encoding a single observation as a new rule).
45. If the storm is attributed to a specific repo's tooling (tq-ladder), file the upstream/systemic fix there, not as a SystemNix patch (fix-upstream doctrine).
46. Keep this report as the baseline if a freeze occurs tonight — journal-cut time vs this timeline is the discriminator (livelock class: no panic, no vmcore).
47. After the storm: add a short post-mortem addendum here (actual driver, duration, whether flm auto-restored) so the next session starts from a closed loop, not open threads.

**Deferred-by-design (48–50)**
48. No config changes proposed tonight — the system behaved as designed end-to-end (guard held, no freeze, flm cleanly down); any zone-threshold retune needs storm-duration data, not a 2:00 AM hunch.
49. No deploys, no lock churn, no input bumps — storm window is exactly when deploys are prohibited (pressure gate would rc=12 anyway).
50. No TODO queue edits until user instruction (explicit user order supersedes the self-harvest default; deferral recorded in §5.10).

---

## 9. g) QUESTIONS ONLY THE USER CAN ANSWER (3)

1. **The CV tq-ladder run** (PID 179529, 99% CPU, `~/projects/CV`, running ~12 min as of 02:50, likely driving the nix-daemon build storm): is this an expected run you want to complete tonight, or should it be stopped / deferred / re-run under `heavy-job` in a quiet window?
2. **`/tmp/server-smoke.mjs` + the nix-email demo VM**: are both yours/expected (bun smoke burning 98% CPU for 37 min from the nsfw-classifier session; qemu demo up 9.9h)? Keep, kill, or move the smoke out of `/tmp` before the tmp-cleaner eats it?
3. **flm recovery preference**: wait for storm drain + auto-restore (may not happen if the 3/day restore budget is spent), or do you want a manual `systemctl start fastflowlm.socket` as soon as PSI calms — and is anything overnight depending on flm (PMA LLM commits degrade to heuristic fallbacks while it is down)?

---

## 10. Evidence appendix (raw numbers)

```
/proc/uptime                 147090.06 s  (≈40h51m → boot ≈2026-09-29 09:54 CEST)
/proc/pressure/io            some avg10=56.15 avg60=42.92 avg300=48.71
                             full avg10=49.07 avg60=29.25 avg300=34.38
/proc/pressure/memory        some avg10=0.00 avg60=0.01  (clean)
MemAvailable                 79,545,656 kB (~75.8 GiB)
Swap                         62.2 GiB total / 30.5 GiB free
diskstats 3s delta           nvme0n1 +14 ticks (p6/root +14) — QLC ~47% duty; nvme1n1 +1 (idle)
cgroup io.stat 10s delta     nix-daemon 121.5 MB | clickhouse 2.2 MB | journald 1.7 MB | rest ≈0
Dirty / Writeback            55.5 MB / 0 kB
cumulative since boot        tq-agent-pool 2.63 TB | nix-daemon 947.6 GB | clickhouse 150.4 GB
                             journald 20.8 GB | papdashboard 18.9 GB | pd-daemon 18.2 GB
                             immich 15.6 GB | PMA 12.2 GB | systemd-coredump 11.9 GB | docker 10.1 GB
top CPU @02:50               tq-ladder.sh (CV) 99.4% / bun /tmp/server-smoke.mjs 98.5% (37min)
                             crush -y ×≥11 | helium 24.3% | clickhouse 9.0% | qemu demo 9.9h
flm unit timeline (paste)    socket 02:10:38→02:11:36 (57.7s; Accepted 133, Refused 8 lifetime)
                             backend 02:14:57 start → serve 02:16:30 → stop 02:19:39 → down 02:19:41
                             21.7G read, 30.8G mem peak, 27.8s CPU — clean cold load, clean stops
guard line (paste, cut)      "MEMORY EMERGENCY still active (I/O PSI some avg60=54.35% sustained
                             (max disk busy 77.3%, MemAvaila…"
```

*Report generated 2026-10-01 05:38 CEST. No follow-ups harvested to TODO_LIST per explicit user hold ("report, THEN WAIT"); see §5.10 / §8.43.*
