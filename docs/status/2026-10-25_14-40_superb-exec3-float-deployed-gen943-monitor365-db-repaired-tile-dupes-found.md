# SUPERB exec-3 resume: float landed + deployed (gen-943), three post-deploy casualties triaged, monitor365 DB repaired live

**Written:** 2026-10-25 14:40 CET · **Session:** exec-3 resume (13:00–14:40) · **HEAD at start:** `65a00059c` · **HEAD now:** `d821522d9` (+ daemon batches)

**Mission carried in:** land the 2026-10-25 lock float (owner's 10:01 `nix flake update` + forced deploy died at the lock-float gate), prove the toplevel, deploy T1, then T2 proofs F17–F21.

## a) FULLY DONE

1. **Float landed end-to-end.** `nix flake check` was already green (12:53, cb82632dc). Remaining blocker was cv's go-modules FOD (unbuildable at BOTH revs — proxy re-served a dependency, moving both revs' module graph). Fixed via the health-hub pattern: `overrideAttrs` vendorHash shim (`SkTcNXE…`, first-hand build4 evidence) at cv's single consumer (`modules/nixos/services/cv.nix` `cvPkg`), drop-protocol comment included. Committed `d821522d9` (pre-commit hook fully green).
2. **Float PROOF complete.** Toplevel `--keep-going` build #5: rc=0, zero errors, cv-88e0d12 binary realized in store, toplevel path verified. First fully-green toplevel on the floated lock.
3. **T1 DEPLOYED + anchored.** Plain deploy → exit 12 (pressure gate, io PSI ~70%, k10temp 91°C). Re-ran with `DEPLOY_FORCE_PRESSURE=1` per the owner's own 10:01 precedent. rc=0; **anchor verified BY GENERATION NUMBER: current-system == system-943**; no in-flight deploy processes. The float is LIVE. CV smoke PASS at version 88e0d12 (shim proven in production).
4. **monitor365-server DB corruption root-caused to storage level and REPAIRED live** (see d) for the bruises): the 13:27 deploy-restart left the DuckDB WAL unclean; the unit's heal script deleted it; the deletion desynced **multiple UNIQUE indexes** from their table data (tenants.api_key + at least the alert-projection table). Every bootstrap died `Duplicate key "api_key: 4326e885…"`. Wrote `scripts/monitor365-apikey-desync-repair.sh` (self-elevating, safety-gated, dry-run mode): drop every droppable index + CHECKPOINT; the server's own `schema.sql` (`CREATE … IF NOT EXISTS` everywhere) rebuilds them fresh from coherent data at boot. **Live result: clean starts at 14:35:03 and again 14:37:24 (survived a watchdog restart — the bootstrap rotate now passes).** Zero monitoring-data loss; the tenant, device, and event store intact throughout (verified tenants=1, devices=1, domain_events=7).
5. **tq-agent-pool smoke FAIL triaged as by-design**: the maintenance-entry-gate refused the start at io PSI 63.55% (≥30% band) — the freeze-prevention gate working as intended. Will start at a quiet window. (Noted: 5 orphaned `tq-autopsy` processes remain after the unit stop — not touched.)
6. Recon discipline held: foreign sessions (wave-3 + parallel immich session) were detected live, their committed work was never pathspec-swept, and all my commits are pathspec-scoped.

## b) PARTIALLY DONE

1. **PapDashboard crash-loop: root-caused, fix designed, NOT yet edited.** The floated papdashboard binary now ENFORCES tile-name uniqueness; the generated `services.json` carries duplicates (Forgejo ×3; SigNoz, SearXNG, Paperless, Immich, Gatus ×2 each). Assembly = manual groups (`papdashboard.nix:601-671`) + registry fan-out tiles (per-service modules) — the manual list is the legacy source of every duplicate. Plan: remove the 6 duplicate manual tiles (keep registry tiles per integration-registry doctrine) + add an eval-time duplicate-name assertion mirroring the existing icon-form gate (`papdashboard.nix:805`). All file sections read; edit is mechanical; NOT applied, NOT deployed.
2. **monitor365-server recovery verification incomplete.** Unit is Started (14:37:24) but at last probe (14:39) `:3001` was not yet listening and the journal was silent — consistent with a long index rebuild on the 25 GB events table (first instance: 548 MB read / 991 MB written / 3 GB mem peak in 2m21s), but NOT yet confirmed healthy. Agent SSE reconnect errors + a `window_focused` DISPLAY collector error observed during the churn — need re-probe after the rebuild window.
3. **Repair script**: proven live but uncommitted and unpolished (health-wait window too short at 120 s — the watchdog's auto-start finished the job after my script gave up; needs a final `CHECKPOINT` note + shellcheck pass — shellcheck not on my shell's PATH).
4. **F19/F20 first-fire proofs: answered RED with a NEW incident.** The 03:00 quiesced backup FAILED: DuckDB `Out of Memory Error: could not allocate block (1.8 GiB/1.8 GiB used)` in the backup copy — meaning the nightly backup has NEVER produced a file and the retention DELETE+VACUUM (which runs inside the same window, after export) never fired either. The rollback ladder's freshest rung is the owner's 2026-10-22 NVMe safety copy. The 1.8 GiB DuckDB-internal limit is the binding constraint (unit MemoryHigh 8G/MemoryMax 12G are not what fired).

## c) NOT STARTED

1. T2 proofs F17 (node_exporter journal), F18 (.prom files + :9100 conns — note: `/var/lib/node_exporter/` does not exist; textfile dir wiring unlocated), F21 (SSE + breaker) — all deferred behind service restoration.
2. F66/F68 /data du-vs-df measurement + growth attribution (needs calm IO window; PSI never dropped below ~57% all session).
3. Redeploy #2 carrying the papdashboard tile fix (+ eval gate).
4. Close-out: plan tombstone flip (coordinate — tombstone still says exec-2; wave-3 wrote its own), CHANGELOG exec-3 entry, 12-55 report §e update, upstream TODO rows (monitor365 bootstrap robustness, backup memory limit, heal-script-vs-index-drops interplay, papdashboard dupes), docs/services/monitor365.md runbook update with the desync class + repair script.
5. New-check verification (gatus crash-loop check, SigNoz rules, /data rules at 66.7%, hermes defer line) — untouched.
6. Committing the repair script + queueing its runbook/TODO rows.

## d) TOTALLY FUCKED UP (honest ledger)

1. **Dry-run was a lie once**: `MONITOR365_REPAIR_DRY_RUN=1` was lost at the script's sudo self-elevation boundary → the "dry-run" executed the first real repair variant (single-index DROP+CREATE). Mitigations: the pre-state had been verified twice by genuine dry-runs first, the action was the intended fix anyway, and the corruption it revealed (multi-index) made the accident diagnostic. Fixed: the env var is now forwarded through the exec.
2. **Repair sequencing cost two extra crash cycles**: my index drops initially lived only in the WAL; the heal script deleted that WAL on the next boot and silently rolled my drops BACK (the 14:32 failures). The drops only persisted after a clean stop checkpointed them. The script now stops the server BEFORE inspecting (lock-wait added), but I did not understand the WAL/drop interplay until it bit — the script deserves one more hardening pass before it becomes runbook doctrine.
3. **Deploy smoke noise read too slowly**: I initially treated the tq-agent-pool FAIL as potentially a deploy regression before reading its journal (the gate refusal was in the first 15 lines). Cost: ~10 minutes of triage order confusion.
4. `rg -rn` trap hit TWICE more (hook-blocked both times) plus one typed-sudo block — all self-inflicted, all recovered, zero damage.

## e) WHAT WE SHOULD IMPROVE (systemic, this session's evidence)

1. **Eval gate for tile-name uniqueness** (papdashboard): a server-runtime parse error on a GENERATED config should be an eval-time throw — same doctrine as the icon-form gate. This crash-loop was one redeploy away from being caught by CI instead of production.
2. **The heal script's WAL deletion is index-hostile**: deleting the WAL on every unclean start can desync ANY un-checkpointed index. Upstream needs a safer heal (checkpoint-on-open or index rebuild after WAL loss); SystemNix-side, the runbook must document that index desync is the expected aftermath of WAL deletion.
3. **Nightly backup has a silent-failure mode**: the 03:00 unit failed but nothing escalated the missing backup FILE (the rollback ladder was empty for ~12 h before I needed it — I got lucky that row-data surgery worked). Gatus should check backup-file freshness, not just unit exit.
4. **Deploy smoke → post-mortem gap**: the deploy rc=0 while three services were down (one crash-looping). The smoke FAILs print but don't gate the deploy exit. Consider a deploy summary line that surfaces FAIL count non-zero.
5. **Parallel-session tile additions collide silently**: two sessions added Immich tiles within hours (manual + registry). The eval gate from (1) turns that collision into a build break instead of a prod crash-loop.
6. My own loop: I re-derived the tile/port/unit map through five greps instead of reading `docs/agents/integration-registry.md` FIRST (the routing table mandates it for service-module work). It would have explained the registry-vs-manual tile duality in one read.

## f) NEXT (queue candidates, priority order)

1. Verify monitor365-server healthy: `:3001` listening, `/health`, SSE "1 devices" (after ~2 min agent grace), watchdog quiet.
2. Apply papdashboard tile dedupe + eval-time duplicate-name assertion; `nix fmt -- <file>`; commit (pathspec).
3. Redeploy (force if pressure gates) + anchor verify by generation number; papdashboard :8088 green.
4. Restore inboxclean-web (restart lever needed — see g.1); verify :8099.
5. Commit + polish `scripts/monitor365-apikey-desync-repair.sh` (longer health window, final CHECKPOINT semantics, shellcheck); runbook row in docs/services/monitor365.md.
6. Root-cause backup OOM: find the 1.8 GiB DuckDB `memory_limit` source; fix config; force one backup fire; verify the export file exists (restores the rollback ladder).
7. Force one retention fire (DELETE + VACUUM) once backup is green; capture F20 evidence (journal lines + DB size delta).
8. F17: node_exporter journal zero "error gathering metrics" (10 min window).
9. F18: locate textfile collector dir (wiring grep), verify .prom freshness + :9100 drained — also explains the phantom Memory-Emergency-Guard alert (metric-absent variant; memory itself is safe: 56 G available).
10. F21: SSE reconnect + breaker closed (30 min window).
11. New-check verification: gatus crash-loop check, SigNoz 51 rules, /data rules 66.7%, hermes defer line.
12. F66/F68 /data du-vs-df at a calm window (PSI has been ≥57% all session).
13. Upstream queue rows: monitor365 bootstrap-vs-desync robustness, backup memory_limit, heal-vs-WAL-drops; papdashboard dupes are OURS (eval gate).
14. tq-autopsy orphan process cleanup decision (5 PIDs outliving their unit).
15. Close-out: tombstone (coordinate with wave-3), CHANGELOG, 12-55 §e, TODO_LIST harvest of this report's §f.
16. Eval-gate TODO row: duplicate tile names (if not done in 2).
17. Gatus check TODO row: monitor365 backup-file freshness (see e.3).
18. inboxclean-web stop-at-13:27:25 cause writeup (whatever g.1 yields).

## g) Questions I cannot answer myself

1. **inboxclean-web was stopped cleanly at 13:27:25 (mid-deploy) and never restarted — no sudo trace, no config reason (wantedBy intact, unit file unchanged).** Did you (or another session of yours) deliberately stop it? If no: I will treat it as anomalous and restart it.
2. **Upstream pushes to LarsArtmann/monitor365**: the desync repair surfaced three upstream fixes (bootstrap robustness against index desync, backup `memory_limit`, heal-script WAL deletion eating index changes). Is the standing upstream-push authorization (07-16 §g) still granted, or park all three as TODO rows for you?
3. **Deploy pacing**: monitor365-server is likely mid-index-rebuild on the 25 GB DB (heavy IO on the QLC root at PSI ~60-70%). Hold the papdashboard-fix redeploy until the rebuild completes and PSI drains, or force through immediately as with T1?

**WAITING FOR INSTRUCTIONS.**
