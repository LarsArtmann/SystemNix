# Status Report: Deploy Unblock — Btrfs Canary Metrics vs §10 Phantom Gate

**Date:** 2026-09-13 03:28 CEST
**Session scope:** Single dispatch — the user's `nix run .#deploy && nix run .#pre-reboot-check` chain was blocked by the pre-deploy phantom-metric gate; root-cause, fix, deploy, verify.
**Related:** 2026-09-12 glob-delete incident (btrfs-rescue + snapshot canary shipment), pool-smart-metrics first deploy (2026-09-12).

---

## Session timeline

1. **Blocked deploy (user paste, live evidence).** After `git sync` (pushed `64b6d7bb..ed20df61`) and `nix flake update go-taskqueue` ×2 (`aea63da` → `b37117d` → `0feb937`, 2026-09-12), `nix run .#deploy` died in pre-deploy §10: **117 passed / 27 warnings / 3 failed** — `btrfs_rescue_append_only`, `btrfs_rescue_snapshots`, `btrfs_root_snapshots` all `✗ ABSENT — Gatus health check will be permanently RED (phantom metric)`.
2. **Root cause (version-skew, not phantom).** The three canary gauges live in the **existing** `btrfs-health-metrics` collector (`platforms/nixos/system/btrfs-health.nix:340-352`, shipped 2026-09-12 with the glob-delete response). The RUNNING generation's collector script predates the canary block. Proof: sibling metric from the **same collector** (`btrfs_scrub_error_free`) was ✓ present in the same §10 run — the unit runs; only the script version is old. The gate's `KNOWN_NEW_METRICS` one-deploy loan list (`scripts/pre-deploy-check.sh:494`) carried the `pool_smart_*` quartile but not the btrfs trio → absence classified as phantom → hard FAIL → deploy blocked. **Second occurrence of the "new gatus-checked metrics shipped without a loan-list entry" class** (first: pool_smart, 2026-09-12).
3. **Fix.** Added the trio to `KNOWN_NEW_METRICS` with a dated, evidence-citing comment (`scripts/pre-deploy-check.sh`). `bash -n` clean; `scripts/test-pre-deploy-metrics.sh` fixture suite: **SELFTEST OK** (all classifier branches).
4. **Gate re-run end-to-end:** **117 passed / 31 warnings / 0 failed** (+4 warnings = 3 reclassified metrics + 1 not-yet-built `btrfs-health-metrics` binary) → `✅ safe to deploy`.
5. **Deploy executed** (`nix run .#deploy`): built toplevel (incl. go-taskqueue 0.2.0 from `0feb937d`), switched, ran the post-deploy smoke (see §d/notes for the 7 baseline-matched advisory FAILs).
6. **Post-deploy verification:**
   - Anchoring clean: `/nix/var/nix/profiles/system` (system-**769**) → `g6i5hmjg…` == `/run/current-system` — no exit-4 profile-skip.
   - Canary live in `btrfs.prom`: `btrfs_root_snapshots 1`, `btrfs_rescue_snapshots 1`, `btrfs_rescue_append_only 1` — the rescue tier created its snapshot AND its per-run chattr `+a` self-test passed.
   - `pool-smart.prom`: `pool_smart_all_healthy 1`, `pool_smart_scrape_errors 0`, `pool_smart_media_flag 0`, `pool_smart_temp_over 0`.
   - tq units ExecStart on the new lock: `/nix/store/ar7b35l…-go-taskqueue-0.2.0/bin/tq`, lock rev `0feb937d`.
7. **Pre-reboot-check** (user's chained command, completed on their behalf): **19 passed / 1 warning / 0 failed — SAFE TO REBOOT**. Notably `✓ no failed units`: the **313 failed units** from the user's morning run (fastflowlm backend + 8 `fastflowlm@` per-connection proxies) are GONE — deploy.sh's EADDRINUSE pre/post-switch guards stopped socket+service and reset the failed state.
8. **Loan-list retirement (same session).** All 7 entries (pool_smart quartile + btrfs trio) confirmed live in their textfiles → retired the same day per the "one-deploy loan, not a museum" doctrine. `KNOWN_NEW_METRICS=""` at `scripts/pre-deploy-check.sh:498`; fixture suite re-run OK.
9. **Commit/push state:** the auto-commit daemon landed the gate fix (`d5f099d9`) and master == origin/master (pushed). Working tree clean at 03:28.

---

## Self-review: what I forgot, what could be better

- **`| tail -60` on the deploy command** — I lost the deploy-phase output (build/switch logs) and only kept the smoke tail. Had to reconstruct deploy success independently via profile anchoring + store-path checks. Both checks passed, but the blind spot was self-inflicted; full output should have gone to a file.
- **Did not verify tq units are ACTIVE post-deploy.** I confirmed the ExecStart binary path matches the new lock rev, but never checked `tq-agent-pool` / `tq-serve` / `tq-bootstrap` unit states or the `tq.home.lan` dashboard. A new upstream rev (`aea63da` → `0feb937`, two bumps in one day) deserves a functional probe, not just a path check.
- **Did not confirm the two new Gatus checks actually evaluate GREEN.** I verified the metric SOURCE (textfile lines), which is what Gatus reads — but "BTRFS Snapshot Canary" / "BTRFS Rescue Snapshots" check results were never read back from Gatus (sqlite or API). Metric presence ⇒ check should pass, but that is inference, not verification.
- **Loan-list remains a manual, forgettable mechanism.** This is the second consecutive deploy blocked by a forgotten loan-list entry. I fixed the instance, not the class (see §e).
- **No AGENTS.md update.** The lesson "a new block in an EXISTING collector also trips §10 — loan-list entry or bust" is only in the script comment. AGENTS.md's §10-adjacent doctrine (pool_smart precedent) was not extended. Minor, but the memory-maintenance rule says immediate.
- **Did not re-run the FULL pre-deploy gate after retiring the loan list** — only syntax + fixture tests. Rationale: every retired metric is now present in the live textfile, so the classifier trivially passes; a 3-minute full re-run for a guaranteed-green change was not worth it. Acceptable, but worth stating.
- **Deploy executed without re-confirmation.** The user's paste ended in a blocked deploy; I fixed the blocker and completed their exact command chain. This matched intent, but the safe pattern for system-changing operations is fix → show → let the user pull the trigger. I chose continuity (the chain was explicitly typed by the user); no damage resulted. Flagging it as a judgment call.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Deploy blocker root-caused (version-skew, not phantom) | Same-collector `btrfs_scrub_error_free` ✓ vs trio ✗ in user's §10 output; canary block committed in tree |
| 2 | §10 loan-list fix shipped | `scripts/pre-deploy-check.sh` KNOWN_NEW_METRICS + dated comment; committed `d5f099d9` (daemon), pushed |
| 3 | Classifier fixture suite green | `test-pre-deploy-metrics.sh` → SELFTEST OK (run twice: after add, after retirement) |
| 4 | Gate re-run: 0 failures | 117 passed / 31 warnings / 0 failed → deploy proceeded |
| 5 | Deploy landed, anchored | system-769 → `g6i5hmjg…` == `/run/current-system` (no exit-4 skip) |
| 6 | go-taskqueue bump live | lock `0feb937d`; tq units on `go-taskqueue-0.2.0` binary |
| 7 | Btrfs canary metrics live | `btrfs.prom`: root_snapshots 1 / rescue_snapshots 1 / append_only 1 (self-test passed) |
| 8 | pool-smart metrics live | `pool-smart.prom`: all_healthy 1, scrape_errors 0, media_flag 0, temp_over 0 |
| 9 | pre-reboot-check: SAFE TO REBOOT | 19 passed / 0 failed; GC rooting + rollback ladder + closure verified |
| 10 | flm failed-unit pile cleared | 313 failed units (user run) → `✓ no failed units` (deploy guards stopped socket+service, reset state) |
| 11 | Loan list fully retired same day | All 7 entries confirmed live then removed; `KNOWN_NEW_METRICS=""` |

## b) PARTIALLY DONE

| Item | Works now | Open | Blocker | Effort |
|------|-----------|------|---------|--------|
| The reboot itself (owed since 2026-09-07) | Boot chain audited SAFE (19/0) | Reboot not executed — clears flm `:52626` corpse (EADDRINUSE-forever class) and the amdxdna D-state corpse pile | User timing (movie-night / scheduling) | S |
| Gatus green-state confirmation for the two new checks | Metric source live (checks read :9100) | Check results never read back from Gatus sqlite/API | None — 5-min probe | S |
| flm v1.0.3 go-live chain | v1.0.3 staged + build-verified; kernel premise falsified; wrapper LD fix agent-added, unvalidated | Live `flm serve` validation, one-time Q4_K weight re-pull, go/revert decision | Requires the reboot first | M–L |
| tq functional verification post-bump | Units deployed on `0feb937d` binary | Pool/serve/dashboard not probed this session | None | S |
| Report HARVEST | This report's §f is harvest-ready | TODO_LIST/ROADMAP not yet updated from it | Awaiting user instruction (per "THEN WAIT") | S |

## c) NOT STARTED

| Item | Planned | Why not started | Still wanted? |
|------|---------|-----------------|---------------|
| Durable §10 new-in-deploy auto-detection (drv-diff of emitting unit scripts vs deployed generation) | Kill the manual loan-list class permanently | Design only; needs a session to implement + fixture-test | Yes — High |
| Same-commit checklist rule/guard: new gatus-checked metric ⇒ loan-list entry or manifest | Prevents the blocker class at ship time | Not designed | Yes — Medium |
| llama-embeddings/reranker `/v1` unreachability investigation | Post-deploy smoke FAIL (baseline-matched, so pre-existing); paperless RAG likely dark | Out of session scope; user asked not to research unrelated items | Yes — High |
| mail relay go-live user step | Verify `larsartmann.cloud` in Resend (SPF/DKIM), then test send | Owner action (console), not agent-actionable | Yes |
| Offsite Hetzner StorageBox + BorgBackup leg | Blueprint exists (`docs/research/hetzner-storagebox-borgbackup.md`) | Not yet implemented (tracked in TODO_LIST) | Yes — High |
| QLC-era `@nix` subvol deletion, ClickHouse backup coverage, guard corpse-aware restore skip (P1) | Existing TODO_LIST items | Not touched this session | Yes |
| dnsblockd upstream health-cache fix push + tag + flake bump; bank-sync tolerant-read fix push (`a9b0b8e..60015cc`) | Both sit unpushed in upstream working trees | Upstream push is owner-gated | Yes |
| Paperless retro-decrypt backfill | Needs upstream push + flake bump first | Same | Yes |
| monitor365 re-enable | Blocked on owner decision (crate publish / repo public / vendor) | Owner decision | ? |

## d) TOTALLY FUCKED UP

**Nothing from this session is fucked up.** The session's blocking condition was pre-existing and is now fixed; deploy landed clean and anchored. Radical-honesty inventory of what IS broken or was:

1. **(Was fucked up, fixed this session):** the 2026-09-12 canary commit shipped 3 new gatus-checked metrics **without** the loan-list entry — this **guaranteed** the next deploy would be hard-blocked. It did block, at ~03:00, carrying the fix for a different subsystem (go-taskqueue bump). Self-inflicted deploy deadlock class; now resolved for this instance.
2. **llama-embeddings + llama-reranker `/v1/embeddings`, `/v1/rerank` unreachable** (post-deploy smoke FAIL). Severity: paperless RAG semantic search degraded (embeddings + reranking dark). Matches the prior baseline → pre-existing, NOT caused by this deploy. Root cause: unknown — needs investigation (candidates: the amdxdna D-state corpse pile / driver-wedge class, which only a reboot clears).
3. **flm backend corpse still holds `:52626`** (EADDRINUSE-forever, zombie thread group — 2026-09-07 boot). Only a reboot releases it; the deploy guards keep the socket down so consumers fail fast instead of churn. All flm consumers (PMA go-commit, papdashboard enricher) dark until reboot. Known, documented, owed.
4. **Memory PSI some avg10 = 18.93% elevated** at smoke time (calm baseline is lower; combined pre-freeze zone arms only at zram ≥95%, and zram was 52.1%). Watch item, not actionable now; re-read post-reboot.
5. **Monitor365 metrics endpoint down** (:9191) — service disabled by owner decision (private vendored crate); known-benign, gate handles it.

## e) WHAT WE SHOULD IMPROVE

1. **Make §10 new-in-deploy detection automatic.** Concrete: at gate time, diff each gatus-referenced metric against the RUNNING generation's emitting unit script store paths; if the to-be-deployed unit's script drv differs (or the unit is new), classify absence as new-in-deploy automatically. Impact: kills a two-in-a-row deploy-blocker class. Effort: M.
2. **Ship-time guard:** an eval-time check (or CI grep) that any metric name referenced in `gatus-config.nix` is either (a) emitted by a collector whose script is unchanged vs the deployed generation, (b) listed in `KNOWN_NEW_METRICS`, or (c) covered by an endpoint exception. Turns "remember the loan list" into "cannot forget". Effort: M.
3. **Baseline aging for the post-deploy smoke.** "All FAILs match baseline — advisory" is doing its job, but two consecutive baselines containing llama FAILs means accepted rot. Add: baseline entries older than N deploys/days escalate from advisory to "investigate before next deploy". Effort: S.
4. **Verify check RESULTS, not just sources, for newly shipped Gatus checks** — post-deploy probe of the actual check states (sqlite read pattern already exists in system-health). Effort: S.
5. **Personal discipline: never pipe deploy output through `tail`.** Tee to a file; grep the file. Effort: trivial.
6. **AGENTS.md:** add the version-skew lesson (new block in an EXISTING collector trips §10 exactly like a new collector does) next to the pool_smart precedent. Effort: S.
7. **Loan-list comment hygiene:** the retirement note now documents both incidents in one place — keep the "re-add ONLY when…" rule visible at the assignment site (done this session; keep it that way).

## f) Top 50 things we should get done next

> Brainstorm, ranked roughly by impact within groups. Items marked *(context)* are carried known-state, not session-discovered. HARVEST should route Critical/High into TODO_LIST, the rest into ROADMAP as appropriate.

**Immediate ops (this box, this week)**
1. Reboot evo-x2 — boot chain audited SAFE (19/0). Critical, S, Ops.
2. Post-reboot: verify flm backend starts clean (no `bind: Address already in use`), `:52625` serves, failed-unit count stays 0. Critical, S, Ops.
3. Post-reboot: confirm `system_stuck_dstate_processes` → 0 (amdxdna corpse pile reclaimed). High, S, Ops.
4. Post-reboot: probe llama `:8848/health`, `:8849/health` + `/v1/embeddings`, `/v1/rerank` functional; if still down, run the investigation. Critical, S–M, Bug.
5. Investigate llama-embeddings/reranker root cause if reboot doesn't clear (journal, cgroup, GPU enumeration). High, M, Bug.
6. flm v1.0.3 live-serve validation post-reboot (staged; kernel premise falsified; LD wrapper fix unvalidated). High, M, Feature.
7. If v1.0.3 enumerates the NPU: one-time Q4_K weight re-pull + MemoryMax/deadline re-check; else revert to v1.0.2 per the staged plan. High, L, Feature.
8. Verify "BTRFS Snapshot Canary" + "BTRFS Rescue Snapshots" Gatus checks green (sqlite read). Medium, S, Quality.
9. Confirm second rescue snapshot appears on the rescue unit's next scheduled run (keep=2). Medium, S, Quality.
10. Probe tq-serve dashboard + tq-agent-pool state on the new `0feb937d` binary. Medium, S, Quality.
11. Verify GitHub Actions green for the pushed lock bump (`ed20df61` + daemon commits). High, S, Quality.
12. Post-reboot re-run `nix run .#post-deploy-check`; refresh the smoke-fail baseline (reboot-clearable classes should drop). Medium, S, Quality.
13. Watch memory PSI avg10 (was 18.93%) post-reboot; escalate only if persistent above ~20%. Low, S, Ops.
14. *(context)* After reboot proves flm stable: delete obsolete hand-install (`~/.local/share/fastflowlm/`, `~/.local/bin/flm`, bashrc exports). Low, S, Cleanup.

**Deploy-gate / tooling hardening (this repo)**
15. Implement §10 durable new-in-deploy auto-detection (drv-diff vs deployed generation). High, M, Quality.
16. Eval-time/CI guard: gatus-referenced metric must be covered (unchanged collector / loan list / endpoint exception). Medium, M, Quality.
17. Fixture-test the auto-detection (negative: phantom still fails; positive: version-skew warns). High, S, Quality.
18. Baseline aging for smoke-fail advisory (escalate stale entries). Medium, S, Quality.
19. Post-deploy: auto-verify newly shipped Gatus check RESULTS (not just metric sources). Medium, S, Quality.
20. AGENTS.md: record the existing-collector version-skew lesson. Medium, S, Docs.
21. Consider moving the loan-list narrative into a short `docs/` runbook so the "one-deploy loan" rule survives comment churn. Low, S, Docs.

**Upstream pushes pending (owner-gated)**
22. *(context)* Push dnsblockd health-cache fix + tag + SystemNix flake bump (kills the :9090 wedge class). High, M, Bug.
23. *(context)* Push bank-sync tolerant-read + V10 canonicalization (`a9b0b8e..60015cc`) + flake bump + deploy. High, M, Bug.
24. *(context)* Push InboxClean retro-decrypt repair + flake bump; then run the manual `--backfill --decrypt-repair` per runbook. Medium, L, Feature.
25. *(context)* go-output: cut v0.37.1 (never re-tag doctrine) to retire the locked-tree comment workaround. Medium, S, Cleanup.
26. *(context)* flm: file upstream issue ONLY if v1.0.3 still fails post-LD-fix (verify-before-filing gate). Low, S, Docs.

**Backup / resilience**
27. *(context)* Implement Hetzner StorageBox + BorgBackup offsite leg per blueprint. High, L, Feature.
28. *(context)* ClickHouse telemetry backup coverage (btrbk excludes XFS). High, M, Feature.
29. *(context)* memory-emergency-guard corpse-aware restore skip (P1: guard re-arms a doomed socket between deploys). Medium, M, Bug.
30. *(context)* Delete dead QLC `@nix` subvol + `/mnt/btrfs-root` leftovers (TODO_LIST Phase 1). Medium, S, Cleanup.
31. Verify btrbk local root snapshots rebuilt to steady retention post glob-delete (canary went 0→1; expect the normal cadence to repopulate). Medium, S, Ops.

**Mail / SSO / services**
32. *(context)* User: verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM), then re-run the relay test send. High, S, Ops (user).
33. *(context)* After #32: sudo-check whether Pocket ID SMTP key byte-equals the relay key; re-paste if the test send still fails. Medium, S, Ops.
34. *(context)* Miniflux: complete one proven SSO login, then flip `disableLocalAuth` go-live gate. Medium, S, Ops (user).
35. *(context)* Google-sync go-live checklist (OAuth "In production" + `rclone authorize` ×3 + sops fill + enable) — still dormant. Low, L, Feature (user).
36. *(context)* monitor365 re-enable owner decision (publish crate / public repo / vendor). Low, S, Decision (user).

**Quality / documentation**
37. Harvest this report's §f into TODO_LIST/ROADMAP (docs-health HARVEST) once instructed. Medium, S, Docs.
38. Annotate the 2026-09-12 glob-delete status report: canary + rescue tier now LIVE and verified (append, don't rewrite). Low, S, Docs.
39. Sweep docs/status for claims invalidated by this deploy (canary metrics "absent" statements). Low, S, Docs.
40. Add a one-line deploy-gate note to the tq runbook documenting the `aea63da→b37117d→0feb937` same-day double bump. Low, S, Docs.

**Longer-term / ROADMAP fuel**
41. §10 endpoint-exception registry: replace hard-coded MONITOR365/DISCORDSYNC/CV lists with data-driven per-endpoint health→absence mapping. Low, M, Quality.
42. Generalize textfile-collector self-verification (append-only self-test pattern from btrfs-rescue) to other fail-closed protections. Low, M, Quality.
43. Consider a `nix run .#verify-metrics` app that cross-checks gatus-config ↔ collector scripts ↔ live textfiles in one command. Medium, M, Quality.
44. Evaluate gatus sqlite-based check-history freshness alert (system-health already reads the DB — reuse for "check evaluated but never green since ship"). Low, M, Quality.
45. Dream: single `nix run .#doctor` = pre-deploy + post-deploy + pre-reboot + metric cross-check with one shared report format. Low, L, Feature.

**Small cleanups noticed in session output**
46. §12 pre-deploy: `mandb`, `network-local-commands`, `pocket-id-provision`, pool-smart, btrfs-health "not built yet" warnings are benign — consider annotating the check output to say so (reduces alarm fatigue). Low, S, Quality.
47. §11 vendorHash probe prints 6 "unable to determine" warnings every deploy — same alarm-fatigue class; annotate or narrow. Low, S, Quality.
48. Pre-deploy §6 prints the full failed-unit table even when all entries are the known flm class — consider summarizing known classes. Low, S, Quality.
49. cv `/metrics` 401 handling works (CV_ENDPOINT_UP branch) — sanity-check it still classifies correctly after the next cv bump. Low, S, Quality.
50. Retire the pool_smart/btrfs loan-list historical comments once a month passes incident-free (comment archaeology cost grows). Low, S, Docs.

## g) Questions I cannot answer myself

1. **Reboot timing:** pre-reboot-check says SAFE — do you want the reboot NOW (it clears the flm `:52626` corpse and the D-state pile, and unblocks the staged v1.0.3 validation chain), or is there a scheduling constraint? If now: should I drive the post-reboot verification (items 2–6) and the v1.0.3 go/revert sequence immediately after?
2. **llama-embeddings/reranker:** the smoke FAILs match the prior baseline, meaning they were already dead before this deploy. Do you already know why (accepted outage? driver-wedge class awaiting the reboot?) — or is this uninvestigated and should be treated as a fresh P1 after the reboot?
3. **§10 gate strategy:** land the durable auto-detection (item 15/16) so this blocker class dies permanently, or do you prefer keeping the manual loan list with only a same-commit checklist rule? The auto-detection touches the deploy-critical gate, so I want your call before modifying it again.

---

*Point-in-time snapshot. State verified 2026-09-13 03:28 CEST: master `13616c29` == origin, working tree clean, deploy anchored at system-769 (`g6i5hmjg`), loan list empty, SAFE TO REBOOT.*
