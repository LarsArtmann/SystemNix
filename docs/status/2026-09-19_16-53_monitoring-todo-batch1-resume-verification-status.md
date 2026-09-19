# Status Report: Monitoring TODO Batch 1 — Resume Session (Verification Phase)

**Date:** 2026-09-19 16:53 CEST
**Session:** continuation of `2026-09-19_12-11_monitoring-todo-batch1-traces-budgets-system-health-overhaul.md` (batch-1 implementation → verification handoff)
**Scope:** SystemNix monitoring domain TODO (`docs/todo/monitoring.md`), host `evo-x2`
**Method:** per house rules — READ → UNDERSTAND → RESEARCH → THINK → REFLECT → Execute; one step at a time, verify each.

---

## 0. What I forgot / could have done better / can still improve

### Forgot (this session)
1. **The ExecStart `--expr` eval ALWAYS trips the documented context-error.** The handoff listed the extraction command as "worked" — in reality it only ever "worked" because the `.drv` path was grepped out of the SAME error's text. I ran it expecting `--print-out-paths` output and got the error instead. Net result is identical (the trap leak is a feature, per AGENTS.md), but I should have written it as the deterministic one-liner from the start: `… 2>&1 | grep -oE '/nix/store/[a-z0-9]+-system-health-metrics\.drv' | head -1`.
2. **No resume state audit.** I jumped straight to step 1 without a 60-second `git log --oneline -5` + `git status`. Evidence I missed it: the freshly extracted drv hash **changed** between sessions (`9wl0y8x4csnjrmx…` → `qz3mpqhiigm55…`). A content-addressed drv hash only moves when the script content OR its inputs (runtimeInputs → nixpkgs) moved. I do not yet know which — this is now investigation item #3. A parallel session, a daemon commit, or a lock bump could all be the cause, and per the concurrent-sessions rule I must attribute before trusting.
3. **Error-output hygiene:** I piped the failing eval through `tail -3`. The drv path survived only because it sat in the last 3 lines — luck, not method. Never filter error-bearing output with `tail`; grep the exact pattern.

### Could have done better (cumulative, batch-1)
- The pre-allowlist smoke test (rc=0, 64.8 s, 656 metric lines) was run BEFORE the allowlist landed — good instinct, but I should have re-run it immediately after the allowlist edit in the same session instead of deferring to the handoff (which then went stale, as proven by the hash drift).
- The daemon's piecemeal commits (`c5cb89b7`, `9624ca20`, `223a13ca`, `d4416e52`) each show "+1 other file" halves I never audited. Commit-per-task discipline exists precisely so this audit is trivial — I should have run `git show --stat` at commit time, not deferred it.
- The stale-drv trap already bit once last session; it cost me again this session. The extraction+build+smoke dance should be one persisted helper script, not a 3-command recall-every-time procedure.

### Can still improve
- Verification debt ordering: nothing in batch 1 is deployable until the post-allowlist smoke passes — that single fact should gate EVERYTHING else (flake check, fmt, housekeeping can proceed in parallel, but no claims of "done" before the smoke).
- The 50-action list from report v1 was good but unpriced; several items (scrub VM test, dashboard generator) are multi-hour and should be explicitly parked behind the cheap verification/housekeeping items.
- Owner questions from report v1 (deploy timing, searxng Type fix, 6h budgets) are still unanswered — they block 3 work streams; I should stop re-deriving them and re-ask explicitly (section g).

---

## 1. This session's actual run (honest — it is small)

| # | Step | Outcome |
|---|------|---------|
| 1 | Recreated tracking todo list per handoff (10 pending + 1 in progress) | ✅ done |
| 2 | Step 1a: extract post-allowlist `system-health-metrics` ExecStart drv | ⚠️ eval errored with the documented context-trap; **drv path leaked and captured: `/nix/store/qz3mpqhiigm55jl77yc6srgdczw0j5hp-system-health-metrics.drv`** |
| 3 | (interrupted) | Build + smoke of the captured drv **NOT yet run** — this report was requested |

**Key finding of this session:** the drv hash differs from the handoff's `9wl0y8x4…` → the collector content or its inputs moved between sessions. The re-extraction the handoff mandated was therefore **mandatory and proven necessary**; the handoff's captured drv was already stale. Investigation pending (diff the two drvs, check `git log` for system-health.nix / flake.lock movement).

Nothing was deployed, nothing was broken, no tree edits were made this session.

---

## 2. Cumulative state (inherited from handoff; verified where noted)

### a) FULLY DONE

| Item | Evidence |
|------|----------|
| Repo + TODO system survey (TODO_LIST queue vs `docs/todo/*` domain libraries) | handoff; TODO_LIST.md lines 65-97 mapped |
| TODO #38 verification — no SigNoz rule hardcodes `maxUpstreamGaps` | zero `upstream_gaps` matches in `_signoz-alerts.nix`; Gatus uses config-driven `signoz_traces_upstream_gaps_over_threshold` gauge |
| TODO #41 verification — traces-coverage Gatus pattern | anchored `[BODY] != pat(*\nsignoz_traces_missing [1-9]*)` confirmed, no hardcoded count |
| signoz-coverage registry edits: renamer ×2 → `wiring="event"`; dnsblockd 26h→6h; bank-sync 26h→6h; onboarding comment | daemon commit `c5cb89b7`; eval-verified via `nix eval --json …services.signoz-coverage.expected`; TODOs #36/#37/#39 resolved by this |
| I/O Stall check annotation (REVIEWED 2026-09-19, do not mute — fix the readers) | `gatus-config.nix` ~line 911, daemon commit `9624ca20` |
| system-health.nix overhaul (implementation): SIGKILL-corpse reap + `mktemp -d` WALK_DIR; `walk_journal()` helper; single-read `emit_service()`; merged CPU+restarts loop; parallel forgejo/PMA×2/pocket-id walks with file handoff + `wait` in oomd block (fail-closed, status ≤1 valid); docker fleet single-inspect (`timeout 5 ps` + one `timeout 10 inspect`); `MemoryMax=256M`; `TimeoutStartSec=5min`; `collectEnabledInactive` + `enabledInactiveAllowlist` options; `scan_inactive_units()` (system + user managers, skips templates/oneshots/socket-activated/allowlist); new Gatus "Enabled-but-Inactive Units" check (anchored pats) | daemon commit `d4416e52`; shellcheck-clean; pre-allowlist smoke rc=0 / 64.8 s / 656 lines with correct fail-closed behavior as user |
| `configuration.nix`: `enabledInactiveAllowlist = [ "searxng-secret-key.service" ]` | daemon commit `223a13ca` |
| Status report v1 with 50 actions + 3 owner questions | `docs/status/2026-09-19_12-11_…md` |
| Textfile `.tmp` audit — **observe half** | live sweep found the corpse inventory below; `btrfs-compression.prom` FRESH (that TODO half healthy) |

### b) PARTIALLY DONE

| Item | Done | Missing |
|------|------|---------|
| Post-allowlist collector verification | fresh drv extracted **this session** (`qz3mpqh…`) | build (`nix build --no-link '<drv>^out'` — runs shellcheck+bash -n) and sed-smoke (`/tmp/shtest2`, assert rc=0 + `system_units_enabled_inactive 0`) |
| Batch-1 gates | — | `nix flake check --no-build`; `nix fmt --no-update-lock-file -- --ci` on the 4 touched files; daemon "+1 file" commit-half audit (`git show --stat c5cb89b7 9624ca20 223a13ca d4416e52`) |
| TODO/CHANGELOG housekeeping | items identified | prune completed (#36, #37, #38, #39, #41, I/O-stall review, .tmp-audit observe half, btrfs-compression healthy) into CHANGELOG.md; re-sync TODO_LIST.md queue; fix 17 malformed `- [ ] **Source:** →` rows; file searxng-secret-key Type=oneshot under `docs/todo/services.md` |
| Textfile `.tmp` audit — fix half | system-health collector now self-reaps | fleet-wide reap (buildcache next); root cleanup of existing corpses (sudo-blocked for me — user one-liners ready); `niri.prom.tmp` user-side trash |
| Backup observability batch 2 | design fully worked out in-session | zero code written |
| Live-state calibration | allowlist calibrated on today's 4 false positives | could be born-red post-deploy if the live unit set shifts before deploy |

### c) NOT STARTED

- Batch 2 code: `backup_ever_succeeded{backup}` (MTIME≠0) in backup-coordination loop; `snapshotSets` option (`{directory, prefix, maxAgeHours, enforced}`); per-set `btrbk_snapshot_{newest_timestamp,age_hours,ever_succeeded,fresh}` gauges with **full `YYYYMMDDTHHMM`** name-parse (mtime fallback; NEVER day-only — a 23:00 snapshot reads 23 h stale at a 26 h threshold); aggregate `btrbk_snapshots_all_fresh` over **enforced** sets only; Gatus "BTRBK Receive Freshness"; sets populated from snapshots.nix (root `@` 26 h; `@home-hermes` 26 h conditional on hermes; data `enforced=false` per the empty-`/mnt/pool/backups/data` EIO stance; pool-services prefix `*` 26 h — basename naming live-confirmed, NOT `services_*`); forgejo-subvol deliberately skipped (owned by `forgejo_subvol_backup_fresh`); `scripts/backup-catchup-report.sh` + flake app entry.
- Batch 3: `crush_hot_db_*` metrics + Gatus in `crush-hot-db.nix`; `churn_rearms_total` → SigNoz guard dashboard panel (signoz-query-lint overlap rules apply); buildcache-gc `buildcache_gc_last_success_timestamp` + `_prune_ok`; pool-usage thresholds (>50 % WARN / >70 % CRIT) in `btrfs-health.nix`; fleet-wide corpse reap; `GOTRACEBACK=all` on discordsync + browser-history; `file_storage` cursor persistence for the SigNoz journald receiver; zero-series sweep script; migrator-gap guard; pool-smart fixture tests; scrub VM test; dashboard generator.
- **Everything deploy-shaped** — owner-gated (Q1 below). Traces Gatus check stays red until a deploy carries the registry flips.

### d) TOTALLY FUCKED UP

Nothing destructive this session or in batch 1 — no data loss, no broken evals, no revert-needed states. Honest near-misses and live hazards, though:

1. **Stale-drv trap cost a second round-trip** (handoff drv already dead at resume). Known trap, codified in AGENTS, still bit — because I trusted a handoff-captured drv instead of re-extracting first thing.
2. **Live textfile-dir pollution (root-owned, sudo-blocked for me):** 21+ `system_health.prom.XXXXXX` 0-byte corpses + `buildcache.prom.bKDc8n`. The NEW system-health collector reaps future corpses, but the existing ones keep the dir dirty until the user runs the cleanup one-liners. Next §10 gate can trip on them if a collector run fails before cleanup.
3. **Unverified daemon commit halves** (`"+1 other file"` on two of my four commits) — if the daemon batched a parallel session's file into `9624ca20`/`d4416e52`, my "my commits are clean" claim is currently unauditable. Low risk (tree was clean at last check) but unproven.
4. **`check_freshness()` day-only parse in snapshots.nix** (~line 669-701): parses `YYYYMMDD` from names → false-stales any same-day-late snapshot at a 26 h threshold. Found, designed around (batch 2 uses full `YYYYMMDDTHHMM`), but the EXISTING checker is still wrong and unfixed.
5. **Born-red risk:** the new "Enabled-but-Inactive Units" Gatus check is calibrated against today's live unit set; if units shift before the deploy that carries it, it pages on arrival.

### e) WHAT WE SHOULD IMPROVE

1. **Resume protocol:** every handoff resume starts with a 60-second state audit (`git log --oneline -8`, `git status`, re-extract any content-addressed artifact) BEFORE executing — never trust a captured drv/lock/eval from a previous session.
2. **One-liner the extraction:** bake the context-error-leak grep into the standard command so step 1 is deterministic (see §0).
3. **Audit daemon commits at commit time,** not at handoff time — `git show --stat` the moment a foreign commit lands on my files.
4. **Deploy-gated honesty:** every "green" claim in this batch is conditional on the deploy; the report and TODO files should carry a "PENDING DEPLOY" tag on all post-flip items (traces check, enabled-inactive check, budgets).
5. **Fixture-first for new checks:** the enabled-inactive check and the batch-2 freshness gauges both deserve a negative-test BEFORE deploy (the repo's negative-test convention exists for exactly the born-red class).
6. **Corpse-reap as a shared library:** three collectors now need the identical mktemp+reap+CAP_FOWNER pattern; extract it once instead of copy-pasting into buildcache, pool-smart, etc.
7. **Monitoring-the-monitor gaps:** buildcache.prom has no reap and no freshness gauges; btrbk freshness has no gauge at all (only the day-only parse checker); the journald receiver re-reads the journal from scratch on every restart (no `file_storage` cursor) — each is a silent-cost item that batch 2/3 addresses.
8. **Stop re-deriving owner questions** — ask once, tag the blocked items, move on (done in §g).

### f) Up to 50 things we should get done next (prioritized)

**Immediate — finish batch-1 verification (this is the gate):**
1. Investigate the drv hash drift: `git log --oneline -8` + `git status` + `git log -1 --format=%H -- modules/nixos/services/system-health.nix flake.lock` — attribute the change (edit vs nixpkgs input) before trusting the new drv.
2. Diff collector behavior implied by the hash change (extract old drv from reflog/daemon if cheap; otherwise just proceed — the new drv IS the tree truth).
3. Build the new drv: `nix build --no-link '/nix/store/qz3mpqhiigm55jl77yc6srgdczw0j5hp-system-health-metrics.drv^out'` (runs shellcheck + `bash -n`).
4. Smoke it: sed-copy to fresh `/tmp/shtest2`, run, assert rc=0, 656± lines, and `system_units_enabled_inactive 0` (allowlist active).
5. Assert the reap logic no-ops cleanly as user (root-owned corpses present in real dir — sed'd test dir must stay clean).
6. `git show --stat c5cb89b7 9624ca20 223a13ca d4416e52` — audit the "+1 file" halves.
7. `nix flake check --no-build` (at quiescence; mind the sops-decrypt eval gotcha).
8. `nix fmt --no-update-lock-file -- --ci` over the 4 touched files; treat any flake.lock diff as churn to revert.
9. Re-verify registry eval: `nix eval --json '.#nixosConfigurations.evo-x2.config.services.signoz-coverage.expected'` (post-any-churn).
10. Confirm gatus-pattern-lint + §10 coverage of the new check via the existing negative-test harness (`scripts/negative-test-lints.sh` shape) — at minimum eyeball that the anchored `\n` forms match the sanctioned pattern classes.

**Housekeeping (cheap, unblocks everything):**
11. Hand the user the root cleanup one-liners (corpses + `buildcache.prom.bKDc8n`); run `trash …/niri.prom.tmp` user-side myself.
12. Prune completed monitoring TODOs → CHANGELOG.md (#36 missing-3 flip, #37 split-semantics, #38 maxUpstreamGaps grep, #39 freshness budgets, #41 pattern verify, I/O-stall review, .tmp-audit observe half, btrfs-compression healthy).
13. Re-sync the monitoring queue section in `TODO_LIST.md` (queue one-liners ↔ library entries must not drift).
14. Fix the 17 malformed `- [ ] **Source:** →` rows across domain files.
15. File `searxng-secret-key` Type=simple→oneshot fix under `docs/todo/services.md` (services domain owns the fix, not monitoring).
16. CHANGELOG entry for the whole batch-1 (collector overhaul + registry flips + new check).

**Batch 2 — backup observability (design complete, code zero):**
17. Add `backup_ever_succeeded{backup}` (MTIME≠0) to the existing backup-coordination loop.
18. Declare the `snapshotSets` option (`directory, prefix, maxAgeHours, enforced`) in backup-coordination.nix.
19. Implement per-set gauges `btrbk_snapshot_{newest_timestamp,age_hours,ever_succeeded,fresh}` with full `YYYYMMDDTHHMM` parse + mtime fallback.
20. Aggregate `btrbk_snapshots_all_fresh` over enforced sets ONLY.
21. Gatus "BTRBK Receive Freshness" check (anchored pats, gatus-pattern-lint clean).
22. Populate sets from snapshots.nix truth: root `@` 26 h; `@home-hermes` 26 h (hermes-conditional); data `enforced=false`; pool-services prefix `*` 26 h (basename naming).
23. Document the forgejo-subvol skip (owned by `forgejo_subvol_backup_fresh`).
24. `scripts/backup-catchup-report.sh` + flake app entry.
25. Eval/fixture negative-test: the empty data set stays gauge-visible but check-invisible (EIO stance).
26. Fix `check_freshness()` day-only parse in snapshots.nix to full `YYYYMMDDTHHMM` (item d-4).

**Batch 3 — metrics/gaps:**
27. `crush_hot_db_*` metrics + Gatus freshness check in `crush-hot-db.nix`.
28. `churn_rearms_total` panel in the SigNoz guard dashboard (respect signoz-query-lint overlap + one-query-per-panel).
29. buildcache-gc `buildcache_gc_last_success_timestamp` + `_prune_ok` metrics.
30. Corpse-reap for the buildcache collector (fleet-wide reap, buildcache first).
31. Pool-usage Gatus thresholds (>50 % WARN / >70 % CRIT) in `btrfs-health.nix`.
32. `GOTRACEBACK=all` env on discordsync + browser-history units.
33. `file_storage` cursor persistence in the SigNoz journald receiver (`signoz.nix`) + restartTriggers check.
34. Zero-series sweep script (rule PromQL vs metrics store, the phantom-rule class detector).
35. Migrator-gap guard (schema-migration assertion, the 1010-skip class).
36. pool-smart fixture tests into `tests/`.
37. Scrub-deferral VM test.
38. Dashboard generator script revival (deterministic uuid5, one query per panel).
39. Consider `tests/test-signoz-coverage.nix` for the registry contract.
40. Extract the shared textfile mktemp+reap+CAP_FOWNER helper; convert remaining collectors.

**Owner-gated / deferred (blocked, do not start):**
41. Deploy (`nix run .#deploy`) — Q1 below; everything green-post-flip hangs on it.
42. Post-deploy verification plan: traces check green, enabled-inactive check green, §10 pass, §10 new-metric loan correct.
43. searxng-secret-key Type fix implementation — Q2 below.
44. 6 h budget acceptability confirmation — Q3 below.
45. Caddy filelog evidence item (parked, owner).
46. Test-fire the Telemetry Export Failures alert (owner-gated noise).
47. Ingest probes for PapDashboard (owner-gated).
48. Gatus dedup investigation (parked).
49. Fleet-wide corpse-reap sweep completion + `audit-textfile-tmp.sh` extension for the reap pattern.
50. Close-out status report v2 with per-item verification evidence once the deploy lands.

### g) Questions I cannot figure out myself (repeat from report v1 — still unanswered, still blocking)

1. **Deploy policy (Q1):** May I run `nix run .#deploy` once batch-1 verification passes (post-allowlist smoke + flake check + fmt), or do you want to deploy yourself / at a specific window? The traces Gatus check stays red until a deploy carries the registry flips; the new enabled-inactive check also only proves itself post-deploy.
2. **searxng-secret-key (Q2):** OK to change `Type=simple` → `Type=oneshot` in the services domain this session (it defeats the enabled-inactive detector's oneshot exclusion and is a genuine module smell), or leave it allowlisted and parked?
3. **Budget appetite (Q3):** Are the 6 h freshness budgets for dnsblockd + bank-sync acceptable (request-driven emitters can go quiet >6 h without work), or should I play safe at 12 h to avoid flap-vs-staleness arguments post-deploy?

---

## 4. Bottom line

Batch 1 is **implemented and 90 % verified**; the remaining 10 % is exactly three commands (build drv, smoke it, flake check/fmt/commit-audit) plus housekeeping. This session contributed one real finding (the stale-drv-at-resume proof) and one captured drv path; the build+smoke was interrupted by this report. Nothing is deployable until the smoke passes, and nothing flips green until you answer Q1 (deploy). Batches 2-3 are fully designed and untouched.
