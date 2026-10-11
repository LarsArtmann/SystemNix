# 10-03 10:42 kernel-OOM cascade — triage close-out

**Date:** 2026-10-12 (retrospective forensics, 9 days post-event)
**Queue item:** TODO_LIST.md → stability → "Triage the 10-03 10:42 kernel-OOM cascade"
**Task-Queue-ID:** 000001a12d0d936834d2be67d86f00000000

## Verdict (three questions, three answers)

1. **Which consumer crossed the line:** a **~60–70 GB anonymous consumer from the parallel dev session**, NOT the desktop scopes the kernel killed. The kernel OOM at 10:42:44 took `app-niri-sh-3244533.scope` (1.1 GB peak) and at 10:43:55 `helium.service` — combined ~2 GB — yet MemAvailable jumped **7.3 GB → 79 GB between 10:48 and 10:49**. ~70 GB of RAM freed by processes exiting ~5–6 min after the kills, while zram was still 96% full. Only one process class on this box reaches that size: the **uncapped plain `bun test`** (the bun-memory-watchdog incident class, ~70 GB RSS, added as plain user processes — the systemd-run `bunMemoryLimitOverlay` scopes are hard-capped at MemoryMax=8G and therefore CANNOT be this consumer). Exact PID attribution is impossible: the journal for 10-03 is vacuumed (oldest archived entry 2026-10-04 03:38) and the census collector (`system_cgroup_mem_*`) has an ingest gap 07:18 → 17:00 that covers the incident (see §e).
2. **Did oom_score_adj=1000 shield the desktop? NO — the opposite.** The adj=1000 systemd-runs are cgroup-capped at 8G, so they die a silent cgroup-local OOM and never rank in the GLOBAL killer; the global killer then selected desktop units (the niri shell scope + helium) while the real ~70 GB anon holder survived both kills. The "shield" only redirects global-OOM victims if the shielded process is still the largest *eligible* consumer — a capped process is never eligible, so the protection was already spent inside the cgroup boundary.
3. **Freeze-class signature? A real zram-full global-OOM event, but NOT a freeze instance.** The pre-kill trace is the freeze-#1 cliff precondition exactly (zram 79% → 96.5% 10:20–10:27, pinned 96.5% to the kill; MemAvailable 36 → 30 → 13 → 6.7 GB 10:20→10:41; PSI avg10 5–6% pre-kill, 56.3% at 10:47 kill-recovery refault) — but the event SELF-RECOVERED in ~6 min (MemAvailable 79 GB, PSI 0.08% by 10:50). The same day's freeze #12 (14:14) was thermal-leading and unrelated to this OOM. Containment was luck: had the ~70 GB consumer not exited at 10:48:xx, this was freeze-#1 redux.

## Evidence

| Time (10-03) | Observation | Source |
| --- | --- | --- |
| 06:25 | boot start (niri shell scope age 4h16m at kill) | queue item / live diagnosis 10-03 |
| 07:17 | `session-15982.scope` = 30.6 GB (30.4 anon), `user.slice` 47.5 GB, `system.slice` 25.6 GB (nix-daemon 9, tq-agent-pool 8); zram 88.9%, MemAvail 22.4 GB → session exits 07:18, MemAvail 61.8 GB | samples_v4 census (07:17 minute — only census minute of the morning that survived the ingest gap) |
| 07:18–10:20 | chronic pressure: MemAvail oscillates 14–62 GB, zram 78–95% | samples_v4 (guard + node_exporter series) |
| 10:20–10:27 | zram 79.2 → 96.5% (device 62.2 GiB at 50% of 124.3); MemAvail 35.9 GB and falling | guard `zram_fill_percent` series |
| 10:30–10:41 | MemAvail 30.5 → 6.7 GB (~24 GB/11 min growth); zram pinned 96.5% | `node_memory_MemAvailable_bytes` |
| 10:42:44 | kernel OOM kills `app-niri-sh-3244533.scope` (1.1 GB peak, 905 M swap) | 10-03 live diagnosis (journal now gone) |
| 10:43:55 | kernel OOM kills `helium.service` | 10-03 live diagnosis |
| 10:43–10:47 | telemetry gap (collector starved: PSI 56.3% avg10 at 10:47; zram 96.1%) | samples_v4 gaps |
| 10:48 → 10:49 | MemAvailable 9.2 → 79.05 GB; zram 96.1 → 87.7%; zone1 trips counter 54 → 55 (one trip, post-OOM); PSI avg10 56.3 → 1.17% by 10:49 | node + guard series |
| — | census (`system_cgroup_mem_*`) samples ABSENT 07:18 → 17:00 — the SigNoz ingest path itself starved during the pressure window | samples_v4 count-by-hour |

Guard zones 2/3/4/5 fired ZERO trips in 10:00–11:00 (zone3's combo — PSI avg10 ≥40 + zram ≥80 — existed only inside the 10:47–10:48 gap, between 30 s runs).

## Findings

- **f.1 — Census telemetry does not survive the incidents it exists to explain.** The per-cgroup memory census had its ingest gap exactly across the only minutes that matter (07:18→17:00; the surviving 07:17 minute is what bounded the pre-cascade state). The node_exporter-hosted series survived because they ride the direct collector; the census rides the same path but its samples vanish — an ingest/emit starvation under pressure. Follow-up queued (durability ring).
- **f.2 — The desktop had NO protection because its consumers were the *eligible* victims.** helium + niri shell scopes run uncapped at adj=0-class scores; any capped (adj=1000, 8G) neighbor is auto-excluded from global ranking. The 2026-06-19/2026-08-03 user-slice caps (80G/90G) were the right shape but the slice sat below the cap at kill time (the ~70 GB holder lived in the slice — user.slice census 47.5 GB at 07:17 suggests the 80G/90G caps never engaged; the giant's growth 10:30–10:41 (~24 GB) is compatible with a slice approaching but not reaching 80G — unprovable without the census gap).
- **f.3 — bun exposure is now double-covered:** the systemd-run overlay (8G cap) for wrapped runs + bun-memory-watchdog (2026-10-10, SIGKILL ≥16 GiB VmRSS) for plain runs. The 10-03 giant predates the watchdog. No new config work justified by this triage.
- **f.4 — Journal retention cannot answer 9-day-old questions.** journald vacuum dropped 10-03 entirely; every future OOM/freeze triage must harvest the journal SAME-DAY or rely on SigNoz series. Reinforces the crash-autopsy.sh queue item.

## f. Follow-ups

- f.1 → queued: census memory-collector durability ring (local textfile last-N fallback) — TODO_LIST.md + docs/todo/stability.md.
- f.4 → already tracked (crash-autopsy.sh row, 10-11 queue).

## Verification

All series read from `signoz_metrics.samples_v4` / `time_series_v4` (ClickHouse, :9000) with 10-03 07:00–11:05 windows; journal absence verified via `journalctl --since 2026-10-03` (no entries) and archive listing (oldest 2026-10-04 03:38). No coredumps for the window (`coredumpctl`).
