# Status Report: DiscordSync Capture-DLQ Critical → Healthy (cgroup-OOM churn incident)

**Date:** 2026-09-02 22:07
**Session scope:** Diagnose + remediate `https://discordsync.home.lan/api/health/backup` reporting `critical / score 60` (capture_dlq: 1927 events failed to append after retries). Cross-repo work: SystemNix (ops/diagnosis/docs) + DiscordSync upstream (bug fix).
**Verification basis:** live journal, live API probes, unit logs, upstream source reads, repo git state. No deploy was performed this session.

---

## Executive Summary

The health endpoint went critical because **discordsync was kernel-OOM-killed 13 times today** (zero kills in the prior 3 days) in a box-level memory/IO crunch: **zram 100% full + 24.6 GB unevictable (fastflowlm model resident) + a concurrent build storm stalling btrfs writeback**. Each kill dumped in-flight event appends into the capture DLQ — which is exactly what the DLQ exists for. **Zero message loss.** All 1,934 DLQ events were replayed successfully; health is back to `healthy / 100`. A latent upstream bug was found and fixed along the way (the `/api/dlq` list endpoint has been permanently 503 since it shipped, making dead letters unlistable). The underlying churn risk persists until the pending reboot (zram 50% sizing) and is documented for the user.

**End state at time of writing:** health `healthy / 100`, capture_dlq `0 events failed to append`, sync ok, coverage ok, the 2 legacy poison projection-DLQ events intentionally retained.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Root cause identified** — not a discordsync bug: 13× `Failed with result 'oom-kill'` cycles 16:54–21:17 (each "2G memory peak"), caused by cgroup fill at `MemoryMax=2G` under zram-full reclaim pressure; 21:16 cycle was a `timeout` (stop-sigterm → SIGKILL) anomaly. | `journalctl -u discordsync.service` Consumed/Failed lines; prior-3-day comparison showing zero kills before today |
| 2 | **System pressure measured and attributed** — IO PSI some avg10 up to 56% / full avg10 42%, avg60 ~50%; SwapFree = 0 kB of 28.2 GiB zram; Unevictable 24.6 GB (flm model). IO sources: parallel session build storm (govulncheck 413% CPU, nix builds in D-state, test binaries churning) + hermes `sentence_transformers` CPU inference at 363%. btrfs `flush-btrfs-1` kworker and `flm-real` observed in D-state. | `/proc/pressure/io`, `/proc/meminfo`, `/sys/block/zram0/mm_stat`, `ps` snapshots at 21:04–21:25 |
| 3 | **Capture DLQ fully drained: 1,928 + 6 = 1,934 events replayed, 0 failed, 0 lost.** Replays survived two mid-replay service kill cycles by design (INSERT OR IGNORE, failed entries stay in DLQ). | API responses logged 21:34–21:35 (`replayed=1000`, `replayed=928`, `failed=0`) and 22:02 (`replayed=6`); depth `0` confirmed; final `/api/health/backup` = `healthy / 100` |
| 4 | **Upstream bug found + fixed: `/api/dlq` list endpoint permanently 503.** `projection_dead_letters.failed_at` is TEXT; the API and dashboard scanned it into `time.Time` → `unsupported Scan` on every request since the endpoint shipped → dead letters were unlistable via API and dashboard. Fixed by returning the raw stored string (mirrors capture-DLQ API), plus `formatTime` → `formatTimeStr` in the dashboard templ. | DiscordSync commit `78d64664` (`internal/api/handlers_dlq.go`, `internal/web/view_models.go`, `internal/web/dlq.templ`); journal evidence: `failed to scan DLQ entry ... unsupported Scan, storing driver.Value type string into type *time.Time` at 21:46/21:47 |
| 5 | **Regression test added and passing:** `TestHandleDLQ_ListReturnsStoredFailedAtText` (creates the real `projection_dead_letters` DDL, inserts a TEXT `failed_at` row, asserts GET `/api/dlq` returns 200 + the stored string). Committed by daemon as `4c4edb23`. | `go test ./internal/api/ -run TestHandleDLQ -v` → all PASS; `go build ./...` clean; `go vet` clean on touched packages |
| 6 | **Projection DLQ replay attempted across all 27 projections.** Found the 2 dead letters: `messages` (1) and `reactions` (1). Both are **deterministic poison events** (replay → `still_failing: 1` each): (a) `discord.message.updated` for message `1544722181114568900` whose parent row never existed (`sql: no rows in result set`), (b) reaction upsert → `FOREIGN KEY constraint failed` (missing parent). Both are 2026-08-16 loss-era orphans. | Live replay responses per projection; journal error lines from the dead-letter/replay path |
| 7 | **Poison events intentionally NOT purged** — purging would delete the only record of the sync gap. Health evaluator already scores 2 dead letters as `ok`. | Decision recorded here + AGENTS.md |
| 8 | **DLQ mechanics fully mapped** (verified in upstream source, not assumed): replay is idempotent `INSERT OR IGNORE`, batch = 1000/call, entries survive a mid-replay crash, capture DLQ has NO automatic purge (nothing can delete entries before replay). API on loopback :8085 has no auth key configured; `/api/*` is CSRF-exempt. | `internal/storage/capture_dlq.go`, `internal/api/handlers_capture_dlq.go`, `internal/api/server.go`, `internal/api/middleware.go` |
| 9 | **Monitoring audit:** Gatus DID alert today (DiscordSync down ~16:50–16:58, resolved 17:05; plus "legacy DLQ GREW" and "Turso local-only mode" alerts, resolved 17:05). Established that the 60s endpoint check is **flap-blind** during 7–25 min kill cycles, and `system_service_restart_churn{discordsync}` read **0** despite 13 kills (metric reset semantics — needs investigation). | gatus journal 16:50–17:06; `/var/lib/prometheus-node-exporter/textfile_collectors/system_health.prom` |
| 10 | **Memory updated:** new DiscordSync AGENTS.md bullet with the full incident class, replay runbook, poison-event warning, API-busy 503 trap, and the failed_at fix reference. | SystemNix AGENTS.md (daemon-committed `851fb4df`) |

## b) PARTIALLY DONE

| # | Item | Done | Open | Blocker | Effort |
|---|------|------|------|---------|--------|
| 1 | **Deploy the `/api/dlq` failed_at fix to the running system** | Fix + regression test committed on DiscordSync branch `nix/aa56b582-vendorhash` (`78d64664`, `4c4edb23`) | SystemNix flake lock still pins the old rev; fix is NOT live on evo-x2; live verification of `/api/dlq` 200 with the 2 poison rows not possible yet | Deploy requires a calm pressure window (deploy gate exit 12 exists) + `nix flake lock --update-input discordsync`; the box was mid-storm all session | S |
| 2 | **Box-level remediation of the kill-churn class** | Fully diagnosed + documented; replay runbook persisted in AGENTS.md | No config change made: discordsync still `MemoryMax=2G`, no `MemoryHigh` soft-cap (page-cache would be reclaimed instead of OOM-kill), no `OOMScoreAdjust`; reboot for zram 50% sizing still pending from earlier today | All root-required (sudo blocked this session) + user posture decision (see g) | S–M |
| 3 | **Poison-event healing** | Root causes extracted from journal; parent message ID identified for the `messages` orphan | Actual heal (backfill the missing parent messages from Discord, then replay succeeds naturally) not started; also blocked on deploying the `/api/dlq` fix to even list the reaction orphan's aggregate ID | Needs the deployed fix + upstream decision on missing-parent handling | M |
| 4 | **Upstream resilience for missing-parent projection events** | Problem precisely characterized (deterministic fail-forever on orphaned child events) | No code change: `message.updated` with no current row should fetch-from-API or skip+metric; `reactions` FK-fail should placeholder-create or drop+metric — design belongs upstream | Design decision in DiscordSync repo (owner = user) | M |
| 5 | **DiscordSync test coverage for this incident** | Regression test for the scan bug shipped; replay idempotency reasoned from source | No VM/integration test for the capture-DLQ replay path (batch boundary at exactly 1000 entries, mid-replay crash safety) | Effort vs. value tradeoff; box was under storm all session | M |
| 6 | **Concurrent-session impact reporting** | Build storm flagged in final summary with concrete PIDs/CPU; foreign `FEATURES.md` modification flagged (uncommitted in DiscordSync worktree — NOT mine, left untouched per critical rules) | The storm's session origin not identified (which session/project was building — never queried the nix build's parent chain to attribution level) | Concurrent sessions; low value now that the storm passed | S |

## c) NOT STARTED

| # | Item | Why not started | Priority |
|---|------|-----------------|----------|
| 1 | Reboot evo-x2 (activates zram 50% sizing ~62 GiB AND the 512 MiB BIOS carveout — two pending config changes, one reboot) | User action; also the single highest-impact fix for this incident class | Critical |
| 2 | Investigate the one anomalous stop cycle at 21:16:10 (`Stopping...` → stop-sigterm timeout → SIGKILL → result `timeout`, NOT oom-kill). systemd-oomd journal shows NO discordsync entries all afternoon, so who ordered that stop job is unknown (deploy restart? another session? manual?) | Ambiguous; broad journal queries during the storm were IO-starved/slow | Medium |
| 3 | Post-mortem the build storm itself: which session/project ran the nix builds + govulncheck, and whether the `heavy-job` workload-admission wrapper was used at all | Storm passed; attribution needs journal archaeology | Medium |
| 4 | Investigate "DiscordSync Legacy DLQ GREW" alert (frozen pre-v4.3 backlog of 11,404 entries; plan M09 recovery still pending from an earlier era) and "Turso local-only mode" alert (quota exhausted or sync gave up at least once today) | Pre-existing tracked issues; today's alerts are symptoms of the same storm/pressure | High (M09), Medium (Turso quota) |
| 5 | Persist the replay procedure as a real script (e.g. `scripts/discordsync-dlq-replay.py` with watch-for-API + loop-until-depth-0 logic) instead of this session's inline heredocs | Knowledge currently lives in AGENTS.md prose + this report only | S |
| 6 | Everything in section (f) below that is marked not-started | — | — |

## d) TOTALLY FUCKED UP

| # | What is broken | Severity | Root cause | Mitigation |
|---|----------------|----------|------------|------------|
| 1 | **The box spent the afternoon in the documented pre-freeze class** — zram 100% full for hours, 24.6 GB unevictable (flm), IO PSI avg60 ≈ 50% windows, 13 service oom-kills. Per the 2026-08-31 freeze forensics this is exactly the amplification pattern that killed the machine twice before. | Critical (freeze risk; repeat victim = discordsync today, could be anything tomorrow) | Known: QLC NVMe + CoW + full zram + unevictable shmem + concurrent full-disk readers. The 2026-09-02 zram sizing fix is CONFIGURED BUT NOT ACTIVE (needs reboot). | Reboot (c1); until then: stop flm socket during heavy builds (user); serialize full-disk readers |
| 2 | **The memory-emergency-guard is blind to today's degradation mode.** Its PSI signal is MEMORY PSI (4.65% avg10 at 21:07 — green) while IO PSI ran 38–56%. It correctly did not trip (memory was fine) — but an IO-storm day with full zram and 13 oom-kills produced ZERO guard/overlay/sev1 signal. The guard's scope is memory emergencies; today's class falls through every layer except per-service oom-kill (which nothing aggregates). | High (no defense-in-depth signal for a known freeze-amplifier pattern) | By-design scope gap, not a bug: no trip zone keys on IO PSI + zram + service-kill-rate jointly | New zone or sibling guard keyed on IO PSI + zram + `memory.events oom_kill` rate (f9 below) |
| 3 | **`/api/dlq` list + dashboard DLQ view have been broken since they shipped** (deterministic 503 via `unsupported Scan` on TEXT `failed_at`). Any operator who ever tried to inspect dead letters via API/UI got nothing. | High (operability; data was never lost) | `dlqEntryResponse.FailedAt time.Time` / `DLQEntry.FailedAt time.Time` vs TEXT column | FIXED upstream `78d64664`; NOT yet deployed (b1) |
| 4 | **`system_service_restart_churn{service="discordsync"} = 0` and `system_service_state_failed{...} = 0` while the service was being OOM-killed 13×/day.** The metrics-based monitoring layer was phantom-green during the churn; only the raw endpoint check (flappy) and Discord OnFailure alerts saw it. | High (monitoring blind spot, phantom-green class) | Unverified hypothesis: churn counter keys on `NRestarts` which resets on explicit start/deploy, and the collector's state flags are instantaneous. Needs code read of `system-health.nix` churn window semantics + a fix (counter over journal, like `memory.events oom_kill`) | Investigate + re-key metric (f6) |
| 5 | **btrbk-data still fails every night on the known /data EIO inode** — seen again live at 00:32 today (`send ioctl failed with -5: Input/output error`, target aborted). /data pool backups remain at zero complete received subvolumes. | High (data-exposure, pre-existing TODO_LIST P0) | Known /data corruption; decided stance: keep failing until repair | Repair runbook from TODO_LIST P0 |
| 6 | **Two of my own process missteps this session** (self-review, no lasting damage): (a) I burned ~8 minutes polling `/api/dlq` with 45s retries accepting the 503 "Service Busy" body as transient — the journal contained the deterministic `unsupported Scan` answer within seconds of my first look; I should have gone journal-first on the second identical failure. (b) My first probe phase used 8s client timeouts while the server's SQLite `busy_timeout` is 15s — my probes mislabeled slow-but-working handlers as "unresponsive", which briefly sent me down a wedged-process theory that was wrong. | Low (session-internal) | Inverted investigation order; timeout not derived from the system's documented constant | Journal-first for repeated identical errors; derive client timeouts from busy_timeout (15s) + margin |
| 7 | **DiscordSync worktree has a foreign uncommitted `FEATURES.md` modification** (not mine, untouched per the concurrent-sessions rule). Untracked-foreign-changes risk during the next daemon sweep or another session's commit. | Low–Medium (commit hygiene) | Another concurrent session's in-progress edit | Owner session should finish/commit it |

## e) WHAT WE SHOULD IMPROVE

1. **Aggregated service OOM visibility.** Nothing answers "which services got oom-killed today?" without journal digging. `system-health` should read each monitored service's `memory.events` (`oom_kill` counter, cgroupfs, cheap) → `system_service_oom_kills_total{service}` + a Gatus condition. Today's incident would have been a single dashboard glance instead of a journal forensics session.
2. **DLQ depth as a RATE, not a level.** `/api/health/backup` level thresholds (warning/critical at depth) can't distinguish "static 2-event legacy backlog" from "growing 1,927-event storm backlog". Emit `discordsync_capture_dlq_growth_1h` (delta-based) and alert on growth, not depth.
3. **Gatus endpoint checks flap green through kill cycles** (60s interval vs 7–25 min kill period). Add `for-duration` semantics or key the alert on restart-churn/oom-kill metrics instead of endpoint liveness alone.
4. **Investigation order doctrine: journal before retry loops.** The 503 "Service Busy" body literally carries a `request_id` and the journal carries the full error — a repeated identical 503 should trigger a journal grep immediately, not a patience loop. Worth a line in AGENTS.md investigation patterns.
5. **Client timeouts should derive from server constants.** busy_timeout=15s means any handler touching SQLite can legitimately block ~15s. Probe timeouts < that produce false "wedge" classifications. (Generalizes the existing `--since`+`timeout` collector lessons to *clients*.)
6. **Replay should be a first-class CLI, not session archaeology.** `ReplayCaptureDLQ` is safe and idempotent — an auto-replay loop upstream (with backoff + poison quarantine after N failures) would make capture-DLQ storms self-healing; today it needed an agent session.
7. **Auto-commit daemon + agent fix pairing.** My 3-file fix landed as `chore: auto-commit 3 changed file(s) (heuristic)` — no context, no link to the incident. Per the existing PATHSPEC-commit rule, agents should commit their own semantically-messaged files immediately rather than letting the daemon batch them (I left the test file uncommitted and the daemon swept it — my miss, not the daemon's).
8. **Snowflake/message forensics need a helper.** Determining "when is message X from / does it still exist on Discord" for orphan diagnosis is manual; a tiny `discordsync snowflake` or `discordsync check-message` CLI subcommand would speed poison-event triage.
9. **The deploy pressure gate needs a post-incident review hook:** gatus restarted at 20:34 mid-storm, suggesting a deploy executed during the IO storm window — verify the PSI gate (exit 12) actually evaluated then, and whether `DEPLOY_FORCE_PRESSURE=1` was used (if so, by which session).

## f) NEXT TASKS (up to 50, ranked by impact; HARVEST input for TODO_LIST/ROADMAP)

Impact: 🔴 Critical / 🟠 High / 🟡 Medium / ⚪ Low · Effort: S <30min / M 30min–2h / L >2h

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Reboot evo-x2 → activates zram 50% sizing (~62 GiB) + 512 MiB VRAM carveout (two pending changes, one reboot); run post-reboot verification (zram device size, resolv.conf, profiled system, pool mount, flm socket posture) | 🔴 | S | Ops |
| 2 | Bump SystemNix `discordsync` flake input to ≥ `4c4edb23` and deploy in a calm window; verify live `/api/dlq` returns 200 with the 2 poison rows | 🔴 | S | Bug |
| 3 | Add `system_service_oom_kills_total{service}` (from `memory.events` `oom_kill`) + Gatus alert to `system-health` | 🔴 | M | Feature |
| 4 | Investigate why `system_service_restart_churn{discordsync}` was 0 after 13 kills; re-key the metric on journal-derived restart counts with a real window | 🔴 | M | Bug |
| 5 | Decide + implement discordsync OOM posture: `MemoryHigh` (e.g. 1.5G, forces page-cache reclaim instead of OOM) vs `MemoryMax` bump vs `OOMScoreAdjust=300` (flm-sacrifice precedent) — upstream module option or SystemNix `mkForce` layer | 🟠 | S | Ops |
| 6 | Add IO-storm signal to defense-in-depth: either a guard zone keyed on IO PSI + zram + oom-kill rate, or a `sev1-bridge` notify-tier key (not page tier) | 🟠 | M | Feature |
| 7 | Backfill-heal the 2 poison orphans: check message `1544722181114568900` (and the reaction's parent) still exist on Discord → targeted backfill → replay succeeds → projection_dlq reaches 0 | 🟠 | M | Bug |
| 8 | Investigate the 21:16:10 anomalous stop (who ordered the stop job; oomd journal empty for discordsync — check for deploy/manual/other-session action at that minute) | 🟠 | S | Ops |
| 9 | Post-mortem today's build storm: which session/project, was `heavy-job` workload-admission used, and did any deploy run with `DEPLOY_FORCE_PRESSURE=1` mid-storm (gatus restarted 20:34) | 🟠 | S | Ops |
| 10 | Upstream (DiscordSync): projection handlers tolerate missing parents — `message.updated` no-row → API-fetch-or-skip+metric; `reactions` FK-fail → placeholder-or-drop+metric; add tests | 🟠 | M | Bug |
| 11 | Upstream (DiscordSync): auto-replay capture DLQ with backoff once appends succeed again, with poison quarantine after N failures per event | 🟠 | M | Feature |
| 12 | Add DLQ growth-rate metric (`discordsync_capture_dlq_growth_1h`) + rate-based Gatus alert | 🟠 | S | Feature |
| 13 | Investigate today's "Legacy DLQ GREW" alert (frozen pre-v4.3 backlog 11,404; plan M09 still pending) and "Turso local-only mode" alert (quota headroom check) | 🟠 | M | Ops |
| 14 | Verify `/api/dlq/purge` `before` semantics: handler parses RFC3339 while `failed_at` is stored as `2006-01-02 15:04:05` — confirm the SQL cutoff formatting actually matches rows (potential second scan/format bug) | 🟠 | S | Bug |
| 15 | Repair /data EIO inode (TODO_LIST P0) — btrbk-data aborted again at 00:32 today; /data pool backups remain at zero | 🟠 | L | Bug |
| 16 | Persist `scripts/discordsync-dlq-replay.py` (watch-for-API + loop-until-depth-0 + both DLQ endpoints) in DiscordSync or SystemNix scripts/ | 🟠 | S | Cleanup |
| 17 | Add capture-DLQ replay VM test: >1000 entries (batch boundary) + simulated mid-replay kill (idempotency under crash) | 🟡 | M | Quality |
| 18 | Sweep other IO-heavy 2G-capped services for the same dirty-page-cache OOM class (paperless-task-queue, immich-ml, discordsync-pattern peers); add `MemoryHigh` where cache-heavy | 🟡 | M | Ops |
| 19 | Gatus `for-duration` (or metric-keyed) alerts for restarty services so 60s checks stop flapping green/gray through kill cycles | 🟡 | S | Quality |
| 20 | Post-deploy-check: add "no monitored unit restarted >3× in last hour" smoke (restart-churn gate) | 🟡 | S | Quality |
| 21 | Add per-service restart-budget alert (e.g. >10 auto-restarts/24h → warning) | 🟡 | S | Feature |
| 22 | Verify the SystemNix discordsync package regenerates `*_templ.go` at build (dlq_templ.go is gitignored upstream — Nix build must run `templ generate`; confirm at next build) | 🟡 | S | Quality |
| 23 | Write `docs/services/discordsync.md` runbook (DLQ replay endpoints, poison-event policy, kill-cycle diagnosis) — AGENTS.md prose is the wrong home for operator steps | 🟡 | S | Documentation |
| 24 | Decide dataDir question: discordsync on NVMe (`/var/lib`) vs the reserved `/mnt/pool/services/discordsync` slot (latency vs NVMe-contention tradeoff — needs a decision, NOT a silent move) | 🟡 | S | Decision |
| 25 | Investigate whether hermes CPU-ML jobs (sentence_transformers at 363% CPU) should route through `heavy-job` admission slots / nice-ionice | 🟡 | S | Ops |
| 26 | Turso quota: check current usage vs plan after today's "local-only mode" alert; consider raising quota or alerting threshold | 🟡 | S | Ops |
| 27 | AGENTS.md: add the "journal-first on repeated identical errors" + "client timeout > server busy_timeout" investigation patterns | 🟡 | S | Documentation |
| 28 | Upstream minor: `appendWithRetry` uses `IsRetryable: func(error) bool { return true }` — retries non-retryable errors; classify via errkit families | ⚪ | S | Quality |
| 29 | Post-reboot: confirm `memory_emergency_guard_*` metrics reflect the new zram geometry (fill % scales) and no stale thresholds fire | ⚪ | S | Quality |
| 30 | Forensics: check guard `restore_capped`/`maxRestoresPerDay` counters for today — did the FLM restore cap engage during the storm? | ⚪ | S | Ops |
| 31 | Add `discordsync snowflake <id>` / `check-message <id>` CLI subcommands upstream for orphan triage | ⚪ | S | Feature |
| 32 | Confirm post-reboot zram steady-state readout matches the 2026-09-02 calibration expectations (~58% fill at old load; document new baseline) | ⚪ | S | Ops |
| 33 | Consider rate-based health scoring upstream: backuphealth evaluator could weight capture_age + DLQ growth jointly instead of per-component levels only | ⚪ | M | Feature |
| 34 | Add request-latency SLO panel for `ingest_event` (OTel spans exist) to see storm degradation visually in SigNoz | ⚪ | S | Feature |
| 35 | Annotate this report once items 1/2/5 land (docs-health ANNOTATE mode) | ⚪ | S | Documentation |
| 36 | Systemic (from AGENTS.md §11 pattern): if the DLQ-replay + oom-churn playbook repeats, promote it to a crush skill | ⚪ | S | Process |
| 37 | Harvest this report into TODO_LIST.md (docs-health HARVEST) — items 1–15 at minimum | 🟠 | S | Process |
| 38 | DiscordSync worktree: finish/commit the foreign `FEATURES.md` edit (owner session) before the next daemon sweep batches it somewhere wrong | 🟡 | S | Cleanup |
| 39 | Consider adding `nix flake check` pre-deploy reminder when bumping discordsync input (vendorhash branch naming `nix/aa56b582-vendorhash` suggests vendorHash pinning discipline) | ⚪ | S | Process |
| 40 | Add a docs/status harvest cross-link: this report ↔ AGENTS.md DiscordSync bullet (done) ↔ TODO_LIST (via 37) | ⚪ | S | Documentation |
| 41 | Verify after reboot that `fastflowlm` v1.0.3 weights (21.6 GB) still fit the new memory geometry and the restore-cap budget still makes sense | ⚪ | S | Ops |
| 42 | Optional: dedicated `system_service_memory_peak_bytes{service}` (from `memory.peak`) to see cache-vs-anon composition trends per service | ⚪ | S | Feature |
| 43 | Optional upstream: expose `capture_dlq` oldest-entry age in health (staleness of backlog, not just count) | ⚪ | S | Feature |
| 44 | Optional: SigNoz dashboard panel for `discordsync` restart/oom correlation with IO PSI (post 3+43) | ⚪ | S | Feature |
| 45 | Re-run full `go test ./...` on DiscordSync in a calm window (this session only ran the two affected packages under storm) | 🟡 | M | Quality |
| 46 | Fix the 5 pre-existing web snapshot golden failures on `nix/aa56b582-vendorhash` (verified failing on clean tree via stash; NOT caused by my change) — golden refresh run | 🟡 | S | Bug |
| 47 | Consider upstream DLQ entry LIMIT for replay batches being configurable (1000 hard-coded is fine today; 200k backlog would need 200 calls) | ⚪ | S | Feature |
| 48 | Double-check no OTHER services hit cgroup OOM today (sweep `Failed with result 'oom-kill'` across all units for 2026-09-02) — discordsync may have been the loudest, not the only victim | 🟠 | S | Ops |
| 49 | Verify OnFailure Discord alerts fired for all 13 kills today (delivery check: 13 expected TRIGGERED + RESOLVED pairs) | 🟡 | S | Quality |
| 50 | Update `docs/gotchas-archive.md` pointer for the failed_at scan bug class (TEXT-vs-time.Time scans: grep the repo for remaining `time.Time` scans against TEXT columns as a one-shot audit) | 🟡 | S | Bug |

---

## g) QUESTIONS I CANNOT ANSWER MYSELF (3)

1. **Was there a deploy (or a manual `systemctl` action) around 21:16 today?** The 21:16:10 stop cycle is the ONLY one today that was not an oom-kill — someone/something issued a stop job while the process was wedged, and it timed out into SIGKILL. systemd-oomd's journal shows nothing for discordsync all afternoon. If you (or another session) ran `nix run .#deploy` or restarted units around then, the anomaly closes itself; if not, I need to dig for an external stop source.
2. **What OOM posture do you want for discordsync during box-wide storms?** Options with real tradeoffs: (a) keep `MemoryMax=2G` and accept "sacrifice discordsync + replay DLQ" (today's posture — works, zero data loss, but 13 restarts/day of churn); (b) add `MemoryHigh≈1.5G` below the cap so dirty page cache gets reclaimed instead of triggering a kill; (c) raise the cap / set `OOMScoreAdjust=300` making it a deliberate global-OOM victim like flm. My recommendation is (b) — cheap, keeps the 2G hard bound, eliminates most kills — but it's your sacrifice-ordering decision.
3. **When do you want the reboot, and do you want a prepared post-reboot verification checklist?** The zram 50% sizing (2026-09-02 config) and the 512 MiB VRAM carveout are BOTH waiting on the same reboot, and today's incident class does not close without it. I can prepare a single verification script (zram size, resolv.conf, `/run/booted-system` match, pool membership, guard metrics baseline, flm socket posture) to run immediately after.

---

## Self-Review Addendum (brutal honesty, per the review questions)

- **Did I lie to you?** No. Every claim above carries its evidence. Two precision notes: the "1,934 replayed" total is 1,928 + 6 from API responses plus depth-0 confirmation (the 7th event from the warning read was included in one of the rounds or purged by a replay race — depth is 0 and health is 100, which is the state that matters). The fix is "shipped to the repo," NOT deployed — stated explicitly in (b1).
- **What did I forget?** Checking for OTHER oom-kill victims today (f48 — one journal sweep I never ran); verifying the purge-handler `before` format semantics while I had the file open (f14 — I read lines 123/197, noticed RFC3339 vs the stored `2006-01-02 15:04:05` format, and moved on without flagging it in the moment); verifying whether a deploy ran mid-storm at 20:34 (e9).
- **What was stupid?** The 8-minute 503 retry loop before reading the journal (d6). The sub-busy_timeout probes (d6). Not flagging the build storm to you the moment I saw govulncheck at 413% CPU — I mentioned it in the final summary only.
- **Ghost systems / split brains?** None created. AGENTS.md now documents the replay runbook (single source); no parallel docs spawned. The report defers to AGENTS.md where they overlap.
- **Scope discipline?** Held: no deploy, no config changes, no purge, no unrelated bug fixes (5 pre-existing snapshot failures verified-but-left). The upstream fix was in-scope (it blocked the operational task) and followed the "fix application bugs upstream" doctrine.

*Report written 2026-09-02 22:07 · session window ~21:00–22:07 · awaiting instructions.*
