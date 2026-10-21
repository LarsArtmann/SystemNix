# Health notifications review — what is broken, root causes, recommended fixes

**Date:** 2026-10-21, ~03:15–03:35 CEST (boot 3e5c8af5, up since Oct 20 14:58)
**Scope:** every health-notification surface on evo-x2 — Gatus (Discord + PapDashboard ingest alerts), SigNoz alert rules (Discord channel), the SEV1 desktop bridge, systemd unit failures, and textfile-collector freshness that feeds the checks.
**Method:** live read-only probes only — `journalctl` (gatus watchdog log, all failed units), node_exporter `/metrics` textfile gauges on 127.0.0.1:9100, SigNoz query/rules API on 127.0.0.1:8080 (no auth), direct HTTP probes (paperless vHost via openssl, papdashboard, geometrikks), `/proc/pressure/*`, `/sys/fs/cgroup` io.pressure walk. No mutations were performed.
**Known limitation:** the Gatus API is OIDC-gated (401) and `gatus.db` is root-only (sudo is tool-guard-blocked), so the **names** of the 25 long-failing endpoints could not be enumerated directly; they are reconstructed from the gatus watchdog journal + live re-probes of every suspected endpoint (see §3).

**Context that frames everything:** the box is (a) **13 hours out of a major incident** — the immich PG-cluster shadow-split, recovered 01:51 tonight ([2026-10-21_01-55](./2026-10-21_01-55_immich-wizard-pg-cluster-shadow-split.md), [self-review 03-10](./2026-10-21_03-10_immich-incident-recovery-self-review.md)) — and (b) **under an ACTIVE I/O storm right now** caused by stacked parallel workloads (see §1). Many of tonight's alerts are downstream symptoms of those two.

---

## 0) Headline state (all live-verified 03:13–03:30)

| Surface | State | Evidence |
| --- | --- | --- |
| Gatus sustained failures | **25 endpoints in long-term error** | `system_gatus_endpoints_in_error_long 25` (node_exporter, fresh) |
| SigNoz rules | **6 of 46 firing** (5 critical, 1 warning) | `/api/v1/rules` on :8080 |
| systemd | **10 units failed** | `node_systemd_unit_state{state="failed"}==1` + journals |
| SEV1 bridge | **2 conditions active** (severity=notify) | `sev1_bridge_alerts_active 2`; journal: "MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" |
| I/O pressure | **ACTIVE storm, worsening**: PSI some avg10 74→86%, full avg10 67→82% across 3 samples | `/proc/pressure/io` @ 03:14/03:16/03:24 |
| CPU temperature | **95–98 °C at the documented pre-crash band** (freeze lineage #8/#9/#11/#12 cut at 98–99 °C) | SigNoz `node_hwmon_temp_celsius{k10temp}` 98; hwmon 95.0 |
| Root filesystem | **90.17 %** — in the auto-prune band since Oct 20 04:32 | df 637G/723G; gatus "Root Auto-Prune Floor (90%)" |
| Memory | OK now (MemAvailable 86G/133G) — alerts were storm-window transients | node_exporter |
| Alert noise | **81 distinct endpoints alerted in 7d; 24h: Monitor365 ×89, InboxClean ×73, I/O ×29, CPU Thermal ×20 trigger events** | gatus watchdog journal |

---

## 1) P0 — the storm itself (live): stacked full-disk readers, zone-6 livelock class

**What is happening:** I/O PSI `some avg10` climbed 74→86% and `full avg10` 67→82% between 03:14 and 03:24 (avg300 already 62% — this is sustained, not a spike). This is exactly the memory-emergency-guard **zone 6** trip class — *"stacked full-disk readers livelocking the scheduler while memory looks healthy"* (crash #3 lineage) — with **6 trips in the last hour** (3819 lifetime, 3676 of them zone-6). Simultaneously k10temp sits at 95–98 °C with the thermal guard tripping 5×/2h, i.e. the box is at the thermal ceiling **and** IO-livelocked at once. Load 11.6–14.

**Prior work this builds on (do not re-diagnose):** yesterday's storm trilogy — [2026-10-20_09-39](./2026-10-20_09-39_qlc-root-space-audit-and-io-storm.md) (R1), [13-43](./2026-10-20_13-43_io-storm-root-cause-tq-agent-pool-oom-churn.md) (R2), [14-16 endgame](./2026-10-20_14-16_storm-round-three-invisible-io-endgame.md) (R3) — already established the mechanism (tq-agent-pool OOM churn + an INVISIBLE kernel-issued component: mmap faults on compressed extents + writeback flusher IO, 326 MB/6s with zero process/cgroup attribution), killed the pool + dispatch sessions, proved the storm persists even with everything idle-demoted, exonerated monitor365 (cgroup IO 0 MB/s; its CPU was an upload-backlog drain) and nix-daemon, exhausted whack-a-mole, and left the owner levers (reboot — taken at 14:42/14:58 — or closing agent terminals) plus the structural cure (rebuildable caches + built trees off the QLC; IO budgets on build cgroups). **Tonight's round is the post-reboot RECURRENCE**: new agent build sessions (below) re-created the stacked-reader condition the trilogy cured — which is itself the strongest evidence yet for the trilogy's structural-cure recommendation over kill-based whack-a-mole.

**Tonight's visible attribution (per-cgroup io.pressure walk + `ps` census at 03:13):**
- `user-1000` cgroup: 76% io.pressure — the storm is user-session workload:
  - `go compile -c=20` at **361% CPU** — crm repo agent session running the full BDD/contract test suite (`~/projects/crm/internal/machineapi`, `httpapi`)
  - `nix build .#checks.x86_64-linux.treefmt --keep-going` + `shellcheck` — CV repo agent session
  - `buildflow` (24.9% CPU)
- fastflowlm read **19.2 GB** from disk across its crash cycles before dying (00:44)
- monitor365-server read/wrote **7.7G/9G** in its final 8.5 min before SIGKILL (03:10)
- weekly `fstrim` ran 31m35s (done 01:27, 79.7 GiB trimmed — it alone tripped the ">30 min" alert at 02:31)
- earlier tonight: the immich recovery rsync (413 MB cluster copy) + 12 writer units restarting

The memory-emergency guard has already intervened: it **stopped** `crush-hot-db-migrate.service` and `discordsync-db-heal.service` mid-run at 03:14 (both 8-min oneshots — they will retry on their timers), and **capped fastflowlm's restore** (the second active SEV1 condition).

**Why this matters:** the no-heavy-builds nix gate was removed by owner directive on 2026-10-14 (live since gen 914) — nothing now rate-limits concurrent agent builds. Tonight shows the consequence shape: multiple agent sessions + timers + a recovery workload stack into the exact livelock class the stability doctrine documented, while the removed gate's escape hatch (`NIX_HEAVY_GATE_FORCE=1`) no longer exists. The box is defending itself (guard + thermal throttling) but is riding the pre-freeze band.

**Recommended fixes (priority order):**
1. **Immediate (owner-gated):** pause/renice the concurrent build sessions (crm test suite, CV checks) until PSI avg10 < 40% — the owner already has `iotop-c` running on pts/2 and appears aware. Do NOT kill by pattern (pkill discipline, 2026-10-17 rule).
2. **Structural:** wrap agent-initiated heavy builds in the existing `heavy-job` mechanism (referenced by the Crush Session Pressure alert text) or a PSI-aware wrapper — the crush session count (8 processes, 6 idle TUIs) is exactly what the Crush Session Pressure check warns about; agent dispatch prompts should require heavy-job wrapping for `nix build`/full test suites.
3. **Per-service IO isolation:** monitor365-server (SQLite pool exhaustion under storm, §4.4) and hermes-db-health (§4.5) are storm victims — consider `ioTier.background` (already used by llama-rag dark-guard) or IOAccounting+io.max on the churning services so one storm cannot wedge the DB-backed fleet.
4. fstrim duration is a symptom, not a cause (31 min on a 90%-full 723G QLC under load is expected); no action beyond the storm fix.
5. **The recurrence gap**: the trilogy's endgame left owner-side levers only — but tonight shows new agent sessions re-arm the storm within a day of a clean reboot. The missing layer is agent-session-side: heavy builds self-gating on PSI (the removed nix shim's agent-layer reinstatement shape, pre-committed in the stability.md gate-removal row as "if freezes return") — tonight's zone-6 trips at the thermal ceiling are the return condition firing.

---

## 2) SigNoz firing rules (6/46) — all six verified legitimate

| Rule | Severity | Verdict | Root cause |
| --- | --- | --- | --- |
| Systemd Service Failed | critical | TRUE POSITIVE | 10 failed units, §4 |
| Service Failure Spike (≥3 failed) | critical | TRUE POSITIVE | same |
| Disk Space Critical (>90%) | critical | TRUE POSITIVE | root at 90.17%, auto-prune engaged Oct 20 04:32; the 10-02 ENOSPC-outage band; what is filling `/` needs the reclaim queue to actually run (55G sits in Trash since Oct 10 per TODO_LIST) |
| SigNoz Trace Coverage Missing | critical | TRUE POSITIVE | `signoz_traces_missing 1`: hermes, monitor365-server, papdashboard, projects-management-automation all stopped reporting spans (`signoz_traces_reporting{...}=0`) — monitor365-server is DOWN (§4.4); the others are downstream of tonight's chaos |
| CPU Thermal Ceiling (≥95 °C 30m) | critical | TRUE POSITIVE | §1 — live, at the pre-crash band |
| Thermal Guard Trip Rate (>1.5/h 2h) | warning | TRUE POSITIVE | 5 trips/2h — same storm |

**Zero phantom-greens or false fires found in the SigNoz layer** — a first: the 2026-08-27 phantom-job-label class and the 2026-10-18 dotted-suffix phantoms are all clean tonight. Route policies verified converged by tonight's provisioner log ("OK 46 route policies — exact one-per-rule, zero orphans"), so Discord delivery for these six is intact.

---

## 3) Gatus — 25 endpoints in sustained error; the alert census

The 25-name enumeration needs a root read of `/var/lib/private/gatus/gatus.db` (queued, §6). From the watchdog journal (24h trigger census) + live re-probes, the sustained-error set decomposes into:

### 3a. Genuinely broken RIGHT NOW (verified)

| Endpoint(s) | Evidence | Root cause → fix |
| --- | --- | --- |
| Monitor365 Server + Agent Connected (89 flaps/24h) | port 3001 dark (`connection refused`, unit failed) | §4.4 — SQLite pool exhaustion → SIGTERM-drain timeout → SIGKILL → failed, not restarted |
| FastFlowLM (5 triggers) | unit failed, `double free or corruption (out)` at 00:43 after ~10 restart attempts since Oct 20 00:09; 31.9G peak, 19.2G read/cycle | §4.3 — C-level heap corruption; crash-loop |
| llama-rag dark-instance family | `llama_rag_leaks_present 1`, `llama_rag_leaked_instances 2` (two live llama-server listeners on 8848+8850), `llama-rag-dark.prom` frozen **11 days** (Oct 10) | §4.6 — the `!cfg.enable` dark-guard timer is dead; leaked servers un-reaped |
| monitor365-backup freshness | `monitor365_backup_healthy 0`, `monitor365_backup_age_hours 999`, `.prom` frozen **80 days** (Aug 2) | §4.7 — collector unit vanished from the system; phantom-red check |
| I/O Stall Rate (29) | PSI §1 | real, live |
| CPU Thermal (20) | §1 | real, live |
| Crush Session Pressure | 8 crush processes (6 idle `crush -y` TUIs) | real, monitor-only by design |
| Stuck D-State (4) | `system_stuck_dstate_processes 3` now | D-state corpses under the storm (documented class; unenumeratable without root) |
| Root Auto-Prune Floor | df 90.17% | real (auto-remediation engaged) |
| fstrim Duration (1) | 31m35s run done 01:27 | storm symptom, resolved |
| SEV1 conditions (4) | memory guard + FLM restore capped | §1 |

### 3b. Fired tonight, ALREADY RECOVERED (verified green by direct probe)

| Endpoint | What happened | Verified state |
| --- | --- | --- |
| **Paperless SSO** | fired 01:51 — paperless ran on the **blank DB cluster** during the immich shadow-split incident (password form back = SSO flow gone) | **GREEN now**: login page carries the Pocket ID OIDC form + auto-submit JS (`social-login` POST to `/accounts/oidc/pocket-id/login/`), probe 03:20 |
| **GeoMetrikks** | fired 01:51 | **GREEN**: `/health/ready` 200, CrowdSec poll loop healthy 03:14 |
| **InboxClean** (73 flaps!) | never down: the service served 200s at **1.5–5.0 s** durations all night; gatus' client timeout fires under IO stalls, then recovers — pure storm flapping | service logs show 200s at 03:13; the InboxClean Health Handler Timeout Burst rule exists for exactly this |
| Memory / ZRAM / OOMD / GPUActive / Niri / EMEET / DAS / LAN / Mail / User / Nix / Build / CV / CrowdSec / Hermes / Boot / oauth2-proxy / mr-sync / llama.cpp / System-Health / Textfile / Health / System / PMA / tq (~25 endpoints × exactly 2 triggers) | boot-window transients: the box rebooted twice Oct 20 (14:42 + 14:58, incident era) and gatus re-sends "initial" alerts on every start for any endpoint failing at that moment — under the storm, many time out at boot | all value-metrics green now (e.g. `node_textfile_scrape_error 0`, niri freshness contract healthy, MemAvailable 86G) |

### 3c. Alert-system findings (the review verdict)

1. **Boot/gatus-restart alert storms**: every gatus restart re-TRIGGERs alerts for ~25+ endpoints that were failing at that instant (the ×2 pattern above) — rebooting under load produces a Discord wall that buries real signals. Recommend: gatus `default-alert.success-before`-style hysteresis (alert only after N successes post-recovery) or an explicit maintenance-window mute for `systemctl restart gatus`/boot windows.
2. **Flap burn**: Monitor365 ×89 + InboxClean ×73 in 24h ≈ 160 Discord notification pairs (trigger+resolve) — failure-threshold 3 at short intervals has no flap suppression. The maintenance-entry-gate family (stability doctrine) is the pattern to extend: suppress re-trigger for checks whose failure is already attributed to an active parent incident (IO storm / SEV1 active).
3. **Enumeration gap (monitoring-the-monitor)**: agents cannot list WHICH endpoints are failing — gatus API is OIDC-401 and gatus.db root-only; only the count (25) is exported. Recommend extending `system-health.nix`'s gatus meta collector to emit `system_gatus_endpoint_in_error{name=...} 1` per failing endpoint (it already opens the DB read-only) — one collector change makes every future incident triage self-service.
4. **SEV1 escalation check**: the 2 active SEV1 conditions (memory guard tripped + FLM restore capped) have been severity=**notify** for hours without a fullscreen page (`page_alerts_active 0`; last page 607s). If the guard being load-bearing for 6 trips/hour is not page-worthy, what is? Owner decision on the escalation threshold.

---

## 4) The 10 failed systemd units — root cause each

| # | Unit | Root cause (from journal) | Classification | Fix |
| --- | --- | --- | --- | --- |
| 1 | `btrbk-data.service` | **DELIBERATE tripwire**: "nightly pool send deliberately SKIPPED (known /data EIO, docs/todo/storage.md P0)" | known, rowed | the T04-T08 /data EIO repair; remove the gate after |
| 2 | `catalog-inventory-sync.service` | `generate-inventory.sh: line 159: bash: command not found` — the unit's PATH lacks bash (nix!) | **agent-fixable bug** | use `${pkgs.bash}/bin/bash` (or add bash to path) at the call site / unit `environment.PATH` |
| 3 | `ci-watchdog.service` | GitHub Actions runner-health canary failing: "GitHub -> Billing & plans (payment method / spending limit)" | **owner action** | GitHub billing console; then `gh workflow run "Runner Health"` |
| 4 | `fastflowlm.service` | `double free or corruption (out)` → SIGABRT core dump; ~10 start attempts since Oct 20 00:09; 31.9G peak | **upstream bug** | disable or pin fastflowlm until fixed (it burns ~19G reads/cycle and its restore is guard-capped anyway — the SEV1 condition); file upstream with the core dump |
| 5 | `hermes-db-health.service` | SQLite integrity census hit its 15-min TimeoutStartSec under the IO storm (367M read) | storm victim | re-run off-peak; consider PSI-gating the timer or raising timeout |
| 6 | `monitor365-server.service` | SQLite `pool acquire failed: timed out` on every background task → graceful-drain timeout (10s) → stop-sigterm timeout → SIGKILL 03:10:59; **still down** (port 3001 refused) | storm victim + shutdown-path bug | restart it once PSI relaxes; upstream: shutdown must not block on pool acquisition (the drain waits on tasks that are themselves pool-blocked); see also §1.3 IO isolation |
| 7 | `service-health-check.service` | meta-check exits 1 because it lists the other failed units | cascade | resolves when 2-6/8-10 clear |
| 8 | `signoz-provision.service` | 2 dashboard updates → HTTP 500 `"cannot begin transaction"` (ai-meter + gcp) — SigNoz's SQLite store under IO pressure; **rules + 46 route policies converged fine**, so Discord alerting is intact | transient, stale-failed | re-run the provisioner (next deploy does it); the 2 dashboards are stale until then |
| 9 | `systemd-bless-boot.service` | `Can't find boot counter source file for '/loader/entries/nixos-dfd029b9….conf'` — the booted entry carries **no boot counter** at bless time | **ALREADY ROWED** — stability.md:213 root-caused it as a same-second race with `boot-mirror-sync`'s counter reverse-propagation (bless operates on `/boot` before the sync copies the loader's `+T` rename in); candidate fix = `After=boot-mirror-sync` ordering. Tonight's 14:58 boot re-confirms the defect is still live: counter decrements unblessed — on a freeze-lineage box the auto-rollback net is arming itself toward fallback | ship the ordering fix from the existing row + fixture legs it asks for |
| 10 | `systemd-tmpfiles-clean.service` | exit 73/CANTCREAT at 15:13 Oct 20 (first run after the 14:58 boot); ran clean at 03:20 the same morning pre-reboot; no failing line logged | post-reboot regression, undiagnosed | rerun with `systemd-tmpfiles --verbose` semantics captured (journal at higher verbosity) to identify the path it cannot create — possibly a tmpfiles line touching a not-yet-mounted hot-tier/DAS path after the incident-era boot ordering |

Plus the two guard-stopped oneshots (not failed, stopped mid-run by the memory guard at 03:14, will retry on timer): `crush-hot-db-migrate`, `discordsync-db-heal`.

---

## 5) Textfile-collector freshness audit

| Collector | Age | Verdict |
| --- | --- | --- |
| `monitor365-backup.prom` | **80 days** (frozen Aug 2) | **broken** — the writer unit has no journal entries at all; likely removed/renamed while its gatus check + backup-coordination entry live on (phantom-red). Fix: either restore the backup+collector or delete the check + coordination entry (verify what monitor365 backups are supposed to be post-Docker-removal) |
| `llama-rag-dark.prom` | **11 days** (Oct 10) | **broken** — the dark-guard timer (`OnCalendar *:0/5`, `mkIf (!cfg.enable)`) is not running on the current system; meanwhile 2 leaked llama-server instances (8848, 8850) sit unreaped. Fix: find why the timer is absent (deploy regression? condition flipped?), reap the leaked servers |
| `btrfs-compression.prom` | 5.7 h | probably benign (looks daily-cadence) — verify owner cadence; no writer found in `modules/` (grep) — confirm it still has an owner at all |
| all ~40 others | fresh (minutes) | healthy; `node_textfile_scrape_error 0` |

---

## 6) Follow-ups (self-harvested at authoring time, per the TODO-system contract)

Harvested to TODO_LIST.md (queue one-liners) + domain libraries (full rows): the gatus per-endpoint error-name collector (monitoring), the gatus restart/boot alert-storm + flap suppression (monitoring), fastflowlm disable-or-pin decision (ai-stack), monitor365-server shutdown-path + IO isolation (services), catalog-inventory-sync bash PATH fix (services), monitor365-backup phantom-red resolution (services), tmpfiles CANTCREAT verbose rerun (stability), SEV1 escalation-threshold owner question (stability), btrfs-compression cadence verify (monitoring), ci-watchdog billing (services, blocked:user). NOT re-harvested (already rowed, live-corroborated instead): bless-boot counter race (stability.md:213 — re-confirmed failing at the Oct 20 14:58 boot), llama-rag dark-guard reliability (stability.md:93 — extended in place with the 11-day-dead-timer + 2 leaked instances evidence). Deliberately NOT harvested because X: hermes-db-health timeout (single storm-window transient, self-retries on next hermes restart), signoz-provision 500s (transient SQLite transaction failures; converges on next deploy by design), fstrim duration (symptom of the storm, run completed), the /data EIO repair and root-disk reclaim (already rowed in storage.md), the immich incident follow-ups (harvested by the 03-10 session).

## 7) What is NOT broken (verified, worth saying)

- **SigNoz alert delivery chain**: 46/46 rules provisioned, exact route-policy convergence, Discord channel + templates healthy — the 2026-08-16 silent-drop class is clean.
- **Gatus itself**: alive, scraping (`system_gatus_results_stale 0`, meta scrape errors 0), config valid.
- **Paperless, GeoMetrikks, InboxClean, papdashboard, health-dashboard hub**: all serving; tonight's alerts on them were incident/storm transients.
- **Memory**: 86G available, zram 32%, no OOMD kills — the "Memory/ZRAM" alert bursts were storm-window transients.
- **The monitoring system caught everything real**: every one of the 6 firing SigNoz rules and every sustained gatus failure maps to a verified live fault. No phantom-green found anywhere tonight — the hard-won lessons (job-label class, dotted suffixes, delta-blindness) are all holding.
